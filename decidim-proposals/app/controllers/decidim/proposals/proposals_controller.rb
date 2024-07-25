# frozen_string_literal: true

module Decidim
  module Proposals
    # Exposes the proposal resource so users can view and create them.
    class ProposalsController < Decidim::Proposals::ApplicationController
      helper ProposalWizardHelper
      helper ParticipatoryTextsHelper
      helper UserGroupHelper
      helper Decidim::Admin::IconLinkHelper
      include Decidim::ApplicationHelper
      include Flaggable
      include Withdrawable
      include FormFactory
      include FilterResource
      include Decidim::Proposals::Orderable
      include Paginable
      include Decidim::AttachmentsHelper

      helper_method :proposal_presenter, :form_presenter, :tab_panel_items

      before_action :authenticate_user!, only: [:new, :create]
      before_action :ensure_is_draft, only: [:preview, :publish, :edit_draft, :update_draft, :destroy_draft]
      before_action :set_proposal, only: [:show, :edit, :update, :withdraw]
      before_action :edit_form, only: [:edit_draft, :edit]
      before_action :set_view_mode, only: [:index]

      before_action :set_participatory_text

      # rubocop:disable Naming/VariableNumber
      STEP1 = :step_1
      STEP2 = :step_2
      # rubocop:enable Naming/VariableNumber

      def index
        if component_settings.participatory_texts_enabled?
          @proposals = Decidim::Proposals::Proposal
                       .where(component: current_component)
                       .published
                       .not_hidden
                       .only_amendables
                       .includes(:category, :scope, :attachments, :coauthorships)
                       .order(position: :asc)
          render "decidim/proposals/proposals/participatory_texts/participatory_text"
        else
          @base_query = search
                        .result
                        .published
                        .not_hidden

          @proposals = @base_query.includes(:component, :coauthorships, :attachments)
          @all_geocoded_proposals = @base_query.geocoded

          @voted_proposals = if current_user
                               ProposalVote.where(
                                 author: current_user,
                                 proposal: @proposals.pluck(:id)
                               ).pluck(:decidim_proposal_id)
                             else
                               []
                             end
          @proposals = reorder(@proposals)
          @proposals = paginate(@proposals)
        end
      end

      def show
        raise ActionController::RoutingError, "Not Found" if @proposal.blank? || !can_show_proposal?
      end

      def new
        enforce_permission_to :create, :proposal
        @step = STEP1
        if proposal_draft.present?
          redirect_to edit_draft_proposal_path(proposal_draft, component_id: proposal_draft.component.id, question_slug: proposal_draft.component.participatory_space.slug)
        else
          @form = form(ProposalForm).from_params(body: translated_proposal_body_template)
        end
      end

      def create
        enforce_permission_to :create, :proposal
        @step = STEP1
        @form = form(ProposalForm).from_params(proposal_creation_params)

        CreateProposal.call(@form, current_user) do
          on(:ok) do |proposal|
            flash[:notice] = I18n.t("proposals.create.success", scope: "decidim")

            @proposal = proposal
            redirect_to "#{Decidim::ResourceLocatorPresenter.new(proposal).path}/preview"
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("proposals.create.error", scope: "decidim")
            render :new
          end
        end
      end

      def preview
        enforce_permission_to :edit, :proposal, proposal: @proposal
        @step = STEP2
        @form = form(ProposalForm).from_model(@proposal)
      end

      def publish
        enforce_permission_to :edit, :proposal, proposal: @proposal
        @step = STEP2
        PublishProposal.call(@proposal, current_user) do
          on(:ok) do
            flash[:notice] = I18n.t("proposals.publish.success", scope: "decidim")
            redirect_to proposal_path(@proposal)
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("proposals.publish.error", scope: "decidim")
            render :edit_draft
          end
        end
      end

      def edit_draft
        @step = STEP1
        enforce_permission_to :edit, :proposal, proposal: @proposal
      end

      def update_draft
        @step = STEP1
        enforce_permission_to :edit, :proposal, proposal: @proposal

        @form = form_proposal_params
        UpdateProposal.call(@form, current_user, @proposal) do
          on(:ok) do |proposal|
            flash[:notice] = I18n.t("proposals.update_draft.success", scope: "decidim")
            redirect_to "#{Decidim::ResourceLocatorPresenter.new(proposal).path}/preview"
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("proposals.update_draft.error", scope: "decidim")
            render :edit_draft
          end
        end
      end

      def destroy_draft
        enforce_permission_to :edit, :proposal, proposal: @proposal

        DestroyProposal.call(@proposal, current_user) do
          on(:ok) do
            flash[:notice] = I18n.t("proposals.destroy_draft.success", scope: "decidim")
            redirect_to new_proposal_path
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("proposals.destroy_draft.error", scope: "decidim")
            render :edit_draft
          end
        end
      end

      def edit
        enforce_permission_to :edit, :proposal, proposal: @proposal
      end

      def update
        enforce_permission_to :edit, :proposal, proposal: @proposal

        @form = form_proposal_params
        UpdateProposal.call(@form, current_user, @proposal) do
          on(:ok) do |proposal|
            flash[:notice] = I18n.t("proposals.update.success", scope: "decidim")
            redirect_to Decidim::ResourceLocatorPresenter.new(proposal).path
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("proposals.update.error", scope: "decidim")
            render :edit
          end
        end
      end

      def withdraw
        enforce_permission_to :withdraw, :proposal, proposal: @proposal

        WithdrawProposal.call(@proposal, current_user) do
          on(:ok) do
            flash[:notice] = I18n.t("proposals.update.success", scope: "decidim")
            redirect_to Decidim::ResourceLocatorPresenter.new(@proposal).path
          end
          on(:has_votes) do
            flash[:alert] = I18n.t("proposals.withdraw.errors.has_votes", scope: "decidim")
            redirect_to Decidim::ResourceLocatorPresenter.new(@proposal).path
          end
        end
      end

      private

      def search_collection
        Proposal.where(component: current_component).published.not_hidden.with_availability(params[:filter].try(:[], :with_availability))
      end

      def default_filter_params
        {
          search_text_cont: "",
          with_any_origin: nil,
          activity: "all",
          with_any_category: nil,
          with_any_state: default_states,
          with_any_scope: nil,
          related_to: "",
          type: "all"
        }
      end

      def default_states
        [
          Decidim::Proposals::ProposalState.where(component: current_component).pluck(:token).map(&:to_s),
          %w(state_not_published)
        ].flatten - ["rejected"]
      end

      def proposal_draft
        Proposal.from_all_author_identities(current_user).not_hidden.only_amendables
                .where(component: current_component).find_by(published_at: nil)
      end

      def ensure_is_draft
        @proposal = Proposal.not_hidden.where(component: current_component).find(params[:id])
        redirect_to Decidim::ResourceLocatorPresenter.new(@proposal).path unless @proposal.draft?
      end

      def set_proposal
        @proposal = Proposal.published.not_hidden.where(component: current_component).find_by(id: params[:id])
      end

      # Returns true if the proposal is NOT an emendation or the user IS an admin.
      # Returns false if the proposal is not found or the proposal IS an emendation
      # and is NOT visible to the user based on the component's amendments settings.
      def can_show_proposal?
        return true if @proposal&.amendable? || current_user&.admin?

        Proposal.only_visible_emendations_for(current_user, current_component).published.include?(@proposal)
      end

      def proposal_presenter
        @proposal_presenter ||= present(@proposal)
      end

      def form_proposal_params
        form(ProposalForm).from_params(params)
      end

      def form_proposal_model
        form(ProposalForm).from_model(@proposal)
      end

      def form_presenter
        @form_presenter ||= present(@form, presenter_class: Decidim::Proposals::ProposalPresenter)
      end

      def form_attachment_new
        form(AttachmentForm).from_model(Attachment.new)
      end

      def edit_form
        form_attachment_model = form(AttachmentForm).from_model(@proposal.attachments.first)
        @form = form_proposal_model
        @form.attachment = form_attachment_model
        @form
      end

      def set_participatory_text
        @participatory_text = Decidim::Proposals::ParticipatoryText.find_by(component: current_component)
      end

      def translated_proposal_body_template
        translated_attribute component_settings.new_proposal_body_template
      end

      def proposal_creation_params
        params[:proposal].merge(body_template: translated_proposal_body_template)
      end

      def tab_panel_items
        @tab_panel_items ||= [
          {
            enabled: @proposal.linked_resources(:projects, "included_proposals").present?,
            id: "included_projects",
            text: t("decidim/budgets/project", scope: "activerecord.models", count: 2),
            icon: resource_type_icon_key("Decidim::Budgets::Project"),
            method: :cell,
            args: ["decidim/linked_resources_for", @proposal, { type: :projects, link_name: "included_proposals" }]
          },
          {
            enabled: @proposal.linked_resources(:results, "included_proposals").present?,
            id: "included_results",
            text: t("decidim/accountability/result", scope: "activerecord.models", count: 2),
            icon: resource_type_icon_key("Decidim::Accountability::Result"),
            method: :cell,
            args: ["decidim/linked_resources_for", @proposal, { type: :results, link_name: "included_proposals" }]
          },
          {
            enabled: @proposal.linked_resources(:meetings, "proposals_from_meeting").present?,
            id: "included_meetings",
            text: t("decidim/meetings/meeting", scope: "activerecord.models", count: 2),
            icon: resource_type_icon_key("Decidim::Meetings::Meeting"),
            method: :cell,
            args: ["decidim/linked_resources_for", @proposal, { type: :meetings, link_name: "proposals_from_meeting" }]
          },
          {
            enabled: @proposal.linked_resources(:proposals, "copied_from_component").present?,
            id: "included_proposals",
            text: t("decidim/proposals/proposal", scope: "activerecord.models", count: 2),
            icon: resource_type_icon_key("Decidim::Proposals::Proposal"),
            method: :cell,
            args: ["decidim/linked_resources_for", @proposal, { type: :proposals, link_name: "copied_from_component" }]
          }
        ] + attachments_tab_panel_items(@proposal)
      end

      def set_view_mode
        @view_mode ||= params[:view_mode] || session[:view_mode] || default_view_mode
        session[:view_mode] = @view_mode
      end

      def default_view_mode
        @default_view_mode ||= current_component.settings.attachments_allowed? ? "grid" : "list"
      end
    end
  end
end
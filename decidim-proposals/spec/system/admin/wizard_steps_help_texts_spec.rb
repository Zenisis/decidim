# frozen_string_literal: true

require "spec_helper"

describe "Manage proposal wizard steps help texts" do
  include_context "when admin manages proposals"

  before do
    current_component.update!(
      step_settings: {
        current_component.participatory_space.active_step.id => {
          creation_enabled: true
        }
      }
    )
  end

  let!(:proposal) { create(:proposal, component: current_component, users: [user]) }

  it "customize the help text for step 1 of the proposal wizard" do
    visit edit_component_path(current_component)

    fill_in_i18n_editor(
      :component_settings_proposal_wizard_step_1_help_text,
      "#global-settings-proposal_wizard_step_1_help_text-tabs",
      en: "This is the first step of the Proposal creation wizard.",
      es: "Este es el primer paso del asistente de creación de propuestas.",
      ca: "Aquest és el primer pas de l'assistent de creació de la proposta."
    )

    click_on "Update"

    visit new_proposal_path(current_component)
    within "#proposal_wizard_help_text" do
      expect(page).to have_content("This is the first step of the Proposal creation wizard.")
    end
  end

  it "customize the help text for step 2 of the proposal wizard" do
    visit edit_component_path(current_component)

    fill_in_i18n_editor(
      :component_settings_proposal_wizard_step_2_help_text,
      "#global-settings-proposal_wizard_step_2_help_text-tabs",
      en: "This is the second step of the Proposal creation wizard.",
      es: "Este es el segundo paso del asistente de creación de propuestas.",
      ca: "Aquest és el segon pas de l'assistent de creació de la proposta."
    )

    click_on "Update"

    create(:proposal, title: "More sidewalks and less roads", body: "Cities need more people, not more cars", component:, users: [user])
    create(:proposal, title: "More trees and parks", body: "Green is always better", component:, users: [user])
    visit_component
    click_on "New proposal"
    within ".new_proposal" do
      fill_in :proposal_title, with: "More sidewalks and less roads"
      fill_in :proposal_body, with: "Cities need more people, not more cars"

      find("*[type=submit]").click
    end

    within "#proposal_wizard_help_text" do
      expect(page).to have_content("This is the second step of the Proposal creation wizard.")
    end
  end

  private

  def new_proposal_path(current_component)
    Decidim::EngineRouter.main_proxy(current_component).new_proposal_path(current_component.id)
  end
end
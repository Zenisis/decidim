# frozen_string_literal: true

module Decidim
  # This cell renders a notification from a notifications collection

  class NotificationCell < Decidim::ViewModel
    include Decidim::Core::Engine.routes.url_helpers

    def show
      if notification.event_class_instance.try(:hidden_resource?)
        render :moderated
      else
        render :show
      end
    end

    def notification_title
      notification.event_class_instance.notification_title
    rescue StandardError
      I18n.t("decidim.notifications.show.missing_event")
    end

    def participatory_space_link
      return unless notification.resource.respond_to?(:participatory_space)

      participatory_space = notification.resource.participatory_space
      link_to(
        decidim_escape_translated(participatory_space.title),
        resource_locator(participatory_space).path
      )
    end

    def action_class
      @action ||= ("#{notification.event_class_instance.action_cell.camelize}Cell" if notification.event_class_instance.action_cell)
    end

    def action_cell
      @action_cell ||= (notification.event_class_instance.action_cell if action_class&.safe_constantize)
    end

    private

    def notification
      @notification ||= Decidim::NotificationPresenter.new(model)
    end
  end
end

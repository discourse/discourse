# frozen_string_literal: true

module PageObjects
  module Components
    class AdminAboutConfigAreaGroupListingCard < PageObjects::Components::Base
      def groups_input
        form.field("aboutPageExtraGroups")
      end

      def initial_members_input
        form.field("aboutPageExtraGroupsInitialMembers")
      end

      def order_input
        form.field("aboutPageExtraGroupsOrder")
      end

      def show_description_input
        form.field("aboutPageExtraGroupsShowDescription")
      end

      def submit
        form.submit
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config_areas.about.toasts.extra_groups_saved"),
        )
      end

      def form
        PageObjects::Components::FormKit.new(
          ".admin-config-area-about__extra-groups-section .form-kit",
        )
      end
    end
  end
end

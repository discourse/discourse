# frozen_string_literal: true

module PageObjects
  module Modals
    class InstallTheme < PageObjects::Modals::Base
      MODAL_CLASS = ".admin-install-theme-modal"

      def modal
        find(MODAL_CLASS)
      end

      def popular_options
        all(".popular-theme-item")
      end

      def create_new_theme(name:, component: false)
        within(MODAL_CLASS) do
          find(".install-theme-item__create").click
          find(".install-theme-content__theme-name").fill_in(with: name)

          type_dropdown = PageObjects::Components::SelectKit.new(".single-select")
          expect(type_dropdown.value).to eq(component ? "components" : "themes")

          click_button(I18n.t("admin_js.admin.customize.theme.create"))
        end
      end

      def choose_remote_repository(url)
        within(MODAL_CLASS) do
          find(".install-theme-item__remote").click
          find(".install-theme-content .repo input").fill_in(with: url)
        end
        self
      end

      def stage_private_theme
        within(MODAL_CLASS) { find(".create-placeholder").click }
      end

      def has_private_theme_actions_disabled?
        has_button?(I18n.t("admin_js.admin.customize.theme.install"), disabled: true) &&
          has_button?(I18n.t("admin_js.admin.customize.theme.create_placeholder"), disabled: true)
      end

      def has_private_theme_actions_enabled?
        has_button?(I18n.t("admin_js.admin.customize.theme.install"), disabled: false) &&
          has_button?(I18n.t("admin_js.admin.customize.theme.create_placeholder"), disabled: false)
      end
    end
  end
end

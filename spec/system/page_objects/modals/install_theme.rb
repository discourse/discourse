# frozen_string_literal: true

module PageObjects
  module Modals
    class InstallTheme < PageObjects::Modals::Base
      MODAL_CLASS = ".admin-install-theme-modal"

      def modal
        browser_root.locator(MODAL_CLASS).filter(visible: true)
      end

      def popular_options
        browser_root
          .locator(".popular-theme-item")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
      end

      def create_new_theme(name:, component: false)
        within_browser(MODAL_CLASS) do
          browser_root.locator(".install-theme-item__create").filter(visible: true).click
          browser_root
            .locator(".install-theme-content__theme-name")
            .filter(visible: true)
            .fill(name)

          type_dropdown = PageObjects::Components::SelectKit.new(".single-select")
          expect(type_dropdown.value).to eq(component ? "components" : "themes")

          browser_root
            .locator(
              "[id=#{I18n.t("admin_js.admin.customize.theme.create").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.create").to_s.to_json}]",
            )
            .or(
              browser_root.get_by_role(
                "button",
                name: I18n.t("admin_js.admin.customize.theme.create"),
              ),
            )
            .filter(visible: true)
            .click
        end
      end

      def choose_remote_repository(url)
        within_browser(MODAL_CLASS) do
          browser_root.locator(".install-theme-item__remote").filter(visible: true).click
          browser_root.locator(".install-theme-content .repo input").filter(visible: true).fill(url)
        end
        self
      end

      def stage_private_theme
        within_browser(MODAL_CLASS) do
          browser_root.locator(".create-placeholder").filter(visible: true).click
        end
      end

      def has_private_theme_actions_disabled?
        have_count(0).does_not_match?(
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{I18n.t("admin_js.admin.customize.theme.install").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.install").to_s.to_json}]",
              ).or(
                browser_root.get_by_role(
                  "button",
                  name: I18n.t("admin_js.admin.customize.theme.install"),
                ),
              ),
            )
            .and(browser_root.locator(":disabled"))
            .filter(visible: true),
        ) &&
          have_count(0).does_not_match?(
            browser_root
              .get_by_role("button")
              .and(
                browser_root.locator(
                  "[id=#{I18n.t("admin_js.admin.customize.theme.create_placeholder").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.create_placeholder").to_s.to_json}]",
                ).or(
                  browser_root.get_by_role(
                    "button",
                    name: I18n.t("admin_js.admin.customize.theme.create_placeholder"),
                  ),
                ),
              )
              .and(browser_root.locator(":disabled"))
              .filter(visible: true),
          )
      end

      def has_private_theme_actions_enabled?
        have_count(0).does_not_match?(
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{I18n.t("admin_js.admin.customize.theme.install").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.install").to_s.to_json}]",
              ).or(
                browser_root.get_by_role(
                  "button",
                  name: I18n.t("admin_js.admin.customize.theme.install"),
                ),
              ),
            )
            .and(browser_root.locator(":not(:disabled)"))
            .filter(visible: true),
        ) &&
          have_count(0).does_not_match?(
            browser_root
              .get_by_role("button")
              .and(
                browser_root.locator(
                  "[id=#{I18n.t("admin_js.admin.customize.theme.create_placeholder").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.create_placeholder").to_s.to_json}]",
                ).or(
                  browser_root.get_by_role(
                    "button",
                    name: I18n.t("admin_js.admin.customize.theme.create_placeholder"),
                  ),
                ),
              )
              .and(browser_root.locator(":not(:disabled)"))
              .filter(visible: true),
          )
      end
    end
  end
end

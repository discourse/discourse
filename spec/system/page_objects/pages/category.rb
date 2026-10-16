# frozen_string_literal: true

module PageObjects
  module Pages
    class Category < PageObjects::Pages::Base
      def visit(category)
        browser_page.goto("/c/#{category.id}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_settings(category)
        browser_page
          .goto("/c/#{category.slug}/edit/settings")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_moderation(category)
        browser_page
          .goto("/c/#{category.slug}/edit/moderation")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_general(category, subcategory = nil)
        if subcategory
          browser_page
            .goto("/c/#{category.slug}/#{subcategory.slug}/edit/general")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        else
          browser_page
            .goto("/c/#{category.slug}/edit/general")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        end
        self
      end

      def visit_edit_template(category)
        browser_page
          .goto("/c/#{category.slug}/edit/topic-template")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_edit_localizations(category)
        browser_page
          .goto("/c/#{category.slug}/edit/localizations")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def visit_categories
        browser_page.goto("/categories").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_new_category
        browser_page
          .goto("/new-category/setup")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_security(category)
        browser_page
          .goto("/c/#{category.slug}/edit/security")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_tags(category)
        browser_page
          .goto("/c/#{category.slug}/edit/tags")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_appearance(category)
        visit_images(category)
        self
      end

      def visit_images(category)
        browser_page
          .goto("/c/#{category.slug}/edit/images")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def back_to_category
        browser_root.locator(".edit-category-page .back-button").filter(visible: true).click
        self
      end

      def save_settings
        if browser_root.locator(".admin-changes-banner").filter(visible: true).count != 0
          browser_root.locator(".admin-changes-banner .btn-primary").filter(visible: true).click
        else
          browser_root.locator("#save-category").filter(visible: true).click
        end
        self
      end

      def toggle_setting(setting, text = "")
        browser_root
          .locator(".edit-category-tab .#{setting} label.checkbox-label")
          .filter(hasText: browser_text_pattern(text))
          .click
        self
      end

      def has_form_template_enabled?
        browser_root.locator(".d-toggle-switch .toggle-template-type").get_attribute(
          "aria-checked",
        ) == "true"
      end

      D_EDITOR_SELECTOR = ".d-editor"

      def has_d_editor?
        have_count(0).does_not_match?(browser_root.locator(D_EDITOR_SELECTOR).filter(visible: true))
      end

      def has_no_d_editor?
        have_count(0).matches?(browser_root.locator(D_EDITOR_SELECTOR).filter(visible: true))
      end

      def has_selected_template?(template_name)
        have_count(0).does_not_match?(
          browser_root.locator(
            ".select-category-template .select-kit-header[data-name='#{template_name}']",
          ).filter(visible: true),
        )
      end

      def toggle_form_templates
        PageObjects::Components::DToggleSwitch.new(".toggle-template-type").toggle
        self
      end

      def toggle_advanced_settings
        PageObjects::Components::DToggleSwitch.new(".d-toggle-switch__checkbox").toggle
        self
      end

      def toggle_checkbox(label_text)
        browser_root
          .locator("label.checkbox-label")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(label_text))
          .click
        self
      end

      def toggle_form_container(title)
        browser_root
          .locator(".form-kit__container")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(title))
          .locator("label.d-toggle-switch__label")
          .filter(visible: true)
          .click
        self
      end

      def select_form_template(template_name)
        browser_root.locator(".select-category-template").filter(visible: true).click
        browser_root
          .locator(".select-kit-collection .select-kit-row")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(template_name))
          .click
        browser_root.locator(".select-category-template").filter(visible: true).click
      end

      def new_topic_button
        browser_root.locator("#create-topic").filter(visible: true)
      end

      def category_box(category)
        browser_root.locator(
          ".category-boxes .category-box[data-category-id='#{category.id}']",
        ).filter(visible: true)
      end

      CATEGORY_NAVIGATION_NEW_NAV_ITEM_SELECTOR = ".category-navigation .nav-item_new"

      def has_no_new_topics?
        have_count(0).matches?(
          browser_root.locator(CATEGORY_NAVIGATION_NEW_NAV_ITEM_SELECTOR).filter(visible: true),
        )
      end

      def has_new_topics?
        have_count(0).does_not_match?(
          browser_root.locator(CATEGORY_NAVIGATION_NEW_NAV_ITEM_SELECTOR).filter(visible: true),
        )
      end

      def click_new
        browser_root.locator(CATEGORY_NAVIGATION_NEW_NAV_ITEM_SELECTOR).filter(visible: true).click
      end

      def click_edit_category
        browser_root.locator(".navigation-controls .edit-category").filter(visible: true).click
        self
      end

      def has_public_access_message?
        contain_text(
          browser_text_pattern(
            I18n.t(
              "js.category.permissions.everyone_full_access",
              everyone_group: ::Group[:everyone].name,
            ),
          ),
          useInnerText: true,
        ).matches?(browser_content)
      end

      def has_no_public_access_message?
        contain_text(
          browser_text_pattern(
            I18n.t(
              "js.category.permissions.everyone_full_access",
              everyone_group: ::Group[:everyone].name,
            ),
          ),
          useInnerText: true,
        ).does_not_match?(browser_content)
      end

      def has_setting_tab?(tab_name)
        tab_css = ".edit-category-#{tab_name}"
        have_count(0).does_not_match?(browser_root.locator(tab_css).filter(visible: true))
      end

      def has_no_setting_tab?(tab_name)
        tab_css = ".edit-category-#{tab_name}"
        have_count(0).matches?(browser_root.locator(tab_css).filter(visible: true))
      end

      def has_changes_banner?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-changes-banner").filter(visible: true),
        )
      end

      def has_powered_by_discourse?
        have_count(0).does_not_match?(
          browser_root.locator(".powered-by-discourse").filter(visible: true),
        )
      end

      def changes_banner_is_clear_of_powered_by_discourse?
        browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          document.querySelector(".admin-changes-banner").getBoundingClientRect().bottom <=
            document.querySelector(".powered-by-discourse").getBoundingClientRect().top
        JS
      end

      def has_category_title?(title)
        contain_text([browser_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator(".category-header h1").filter(visible: true),
        )
      end

      def topic_posting_review_mode_chooser(simplified: true)
        if simplified
          PageObjects::Components::SelectKit.new(
            ".form-kit__field[data-name='category_setting.topic_posting_review_mode'] .combo-box",
          )
        else
          PageObjects::Components::SelectKit.new(".topic-posting-review-mode .combo-box")
        end
      end

      def topic_posting_review_group_chooser(simplified: true)
        if simplified
          PageObjects::Components::SelectKit.new(".form-kit .group-chooser")
        else
          PageObjects::Components::SelectKit.new(".topic-posting-review-mode .group-chooser")
        end
      end

      def has_posting_review_groups_error?
        contain_text(
          browser_text_pattern(I18n.t("js.category.validations.groups_required")),
          useInnerText: true,
        ).matches?(browser_content)
      end

      def has_no_posting_review_groups_error?
        contain_text(
          browser_text_pattern(I18n.t("js.category.validations.groups_required")),
          useInnerText: true,
        ).does_not_match?(browser_content)
      end

      def has_topic_posting_review_mode?(mode, simplified: true)
        topic_posting_review_mode_chooser(simplified: simplified).has_selected_value?(mode)
      end

      def has_topic_posting_review_groups?(group, simplified: true)
        topic_posting_review_group_chooser(simplified: simplified).has_selected_value?(group.id)
      end
    end
  end
end

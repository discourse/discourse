# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmailTemplates < PageObjects::Pages::AdminBase
      def visit
        browser_page
          .goto("/admin/email/templates")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_template(template_id)
        browser_page
          .goto("/admin/email/templates/#{template_id}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_template?(template_name)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(template_name)],
          useInnerText: true,
        ).matches?(browser_root.locator("td").filter(visible: true))
      end

      def click_template(template_name)
        browser_root
          .locator("td")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(template_name))
          .click
        self
      end

      def edit_subject(text)
        browser_root.locator("input.email-template__subject").filter(visible: true).fill(text)
        self
      end

      def has_subject_value?(value)
        expect(
          browser_root.locator("input.email-template__subject").filter(visible: true).input_value,
        ).to eq(value)
      end

      def edit_body(text)
        browser_root.locator(".d-editor-input").filter(visible: true).fill(text)
        self
      end

      def has_preview_content?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".d-editor-preview").filter(visible: true),
        )
      end

      def save_changes
        browser_root.locator(".save-changes").filter(visible: true).click
        self
      end

      def has_multiple_subjects_link?(href)
        link = browser_root.locator(".email-template__has-multiple-subjects").filter(visible: true)
        expect(
          link.evaluate(
            "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
            arg: "href",
          ),
        ).to eq(href)
        expect(link.inner_text.strip).to eq(
          I18n.t("admin_js.admin.customize.email_templates.multiple_subjects"),
        )
      end

      def has_multiple_bodies_link?(href)
        link = browser_root.locator(".email-template__has-multiple-bodies").filter(visible: true)
        expect(
          link.evaluate(
            "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
            arg: "href",
          ),
        ).to eq(href)
        expect(link.inner_text.strip).to eq(
          I18n.t("admin_js.admin.customize.email_templates.multiple_bodies"),
        )
      end

      def has_interpolation_keys?(keys)
        container =
          browser_root.locator(".email-template .interpolation-keys").filter(visible: true)
        keys.each do |key|
          expect(
            container.locator("button").filter(visible: true),
          ).to PlaywrightMatchers.contain_text([browser_text_pattern(key)], useInnerText: true)
        end
        true
      end

      def has_no_interpolation_keys?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".email-template .interpolation-keys").filter(visible: true),
        )
      end
    end
  end
end

# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmailTemplates < PageObjects::Pages::AdminBase
      def visit
        page.visit("/admin/email/templates")
        self
      end

      def visit_template(template_id)
        page.visit("/admin/email/templates/#{template_id}")
        self
      end

      def has_template?(template_name)
        has_css?("td", text: template_name)
      end

      def click_template(template_name)
        find("td", text: template_name).click
        self
      end

      def edit_subject(text)
        find("input.email-template__subject").fill_in(with: text)
        self
      end

      def has_subject_value?(value)
        try_until_success { expect(find("input.email-template__subject").value).to eq(value) }
      end

      def edit_body(text)
        find(".d-editor-input").fill_in(with: text)
        self
      end

      def has_preview_content?(text)
        has_css?(".d-editor-preview", text: text)
      end

      def save_changes
        find(".save-changes").click
        self
      end

      def has_multiple_subjects_link?(href)
        link = find(".email-template__has-multiple-subjects")
        expect(link[:href]).to eq(href)
        expect(link.text).to eq(
          I18n.t("admin_js.admin.customize.email_templates.multiple_subjects"),
        )
      end

      def has_multiple_bodies_link?(href)
        link = find(".email-template__has-multiple-bodies")
        expect(link[:href]).to eq(href)
        expect(link.text).to eq(I18n.t("admin_js.admin.customize.email_templates.multiple_bodies"))
      end
    end
  end
end

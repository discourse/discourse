# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBadges < PageObjects::Pages::Base
      def visit_page(badge_id = nil)
        path = "/admin/badges"
        path += "/#{badge_id}" if badge_id
        browser_page.goto(path).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(browser_page).to have_url(path)
        expect(browser_root.locator(".admin-badge-list").filter(visible: true)).not_to have_count(0)
        self
      end

      def new_page
        browser_page.goto("/admin/badges/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_badge?(title)
        contain_text([browser_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator(".current-badge-header .badge-display-name").filter(visible: true),
        )
      end

      def filter_badges(text)
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(browser_root.locator(".#{"d-filter-controls__input".to_s.split.join(".")}"))
          .filter(visible: true)
          .fill(text)
        self
      end

      def has_badge_in_list?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(".admin-badge-list-item .badge-display-name").filter(visible: true),
        )
      end

      def has_no_badge_in_list?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).does_not_match?(
          browser_root.locator(".admin-badge-list-item .badge-display-name").filter(visible: true),
        )
      end

      def has_no_badges_found_message?
        have_count(0).does_not_match?(
          browser_root.locator(".d-filter-controls__no-results").filter(visible: true),
        )
      end

      def has_saved_form?
        expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.saved"))
      end

      def submit_form
        form.submit
        self
      end

      def delete_badge
        browser_root.locator(".badge-form__delete-badge-btn").filter(visible: true).click
        self
      end

      def choose_icon(name)
        form.choose_conditional("choose-icon")
        form.field("icon").select(name)
        self
      end

      def fill_query(query)
        form.field("query").fill_in(query)
        self
      end

      def upload_image(name)
        form.choose_conditional("upload-image")

        browser_page
          .expect_file_chooser do
            form
              .field("image_url")
              .locator(".file-uploader__controls .btn")
              .filter(visible: true)
              .click
          end
          .set_files(File.absolute_path(file_from_fixtures(name)))

        expect(
          form.field("image_url").locator(".btn-danger").filter(visible: true),
        ).not_to have_count(0)

        self
      end

      def edit_groupings
        browser_root.locator(".edit-groupings-btn").filter(visible: true).click
        self
      end

      def form
        @form ||= PageObjects::Components::FormKit.new("form")
      end
    end
  end
end

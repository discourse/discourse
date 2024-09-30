# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBadges < PageObjects::Pages::Base
      def visit_page(badge_id = nil)
        path = "/admin/badges"
        path += "/#{badge_id}" if badge_id
        page.visit path
        self
      end

      def new_page
        page.visit "/admin/badges/new"
        self
      end

      def has_badge?(title)
        page.has_css?(".current-badge-header .badge-display-name", text: title)
      end

      def has_saved_form?
        expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.saved"))
      end

      def submit_form
        form.submit
        self
      end

      def delete_badge
        page.find(".badge-form__delete-badge-btn").click
        self
      end

      def choose_icon(name)
        form.choose_conditional("choose-icon")
        form.field("icon").select("truck-medical")
        self
      end

      def fill_query(query)
        form.field("query").fill_in(query)
        self
      end

      def upload_image(name)
        form.choose_conditional("upload-image")

        attach_file(File.absolute_path(file_from_fixtures(name))) do
          form.field("image_url").find(".image-upload-controls .btn").click
        end

        expect(form.field("image_url")).to have_css(".btn-danger")

        self
      end

      def edit_groupings
        page.find(".edit-groupings-btn").click
        self
      end

      def form
        @form ||= PageObjects::Components::FormKit.new("form")
      end
    end
  end
end

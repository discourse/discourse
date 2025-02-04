# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminPermalinkForm < PageObjects::Pages::Base
      def fill_in_url(url)
        form.field("url").fill_in(url)
        self
      end

      def fill_in_description(description)
        form.field("description").fill_in(description)
        self
      end

      def select_permalink_type(type)
        form.field("permalinkType").select(type)
        self
      end

      def fill_in_category(category)
        form.field("categoryId").fill_in(category)
        self
      end

      def click_save
        form.submit
        expect(page).to have_css(
          ".admin-permalink-item__url",
          wait: Capybara.default_max_wait_time * 3,
        )
      end

      def form
        @form ||= PageObjects::Components::FormKit.new(".admin-permalink-form .form-kit")
      end
    end
  end
end

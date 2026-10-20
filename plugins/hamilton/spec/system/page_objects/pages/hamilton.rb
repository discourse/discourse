# frozen_string_literal: true

module PageObjects
  module Pages
    class Hamilton < PageObjects::Pages::Base
      def visit
        page.visit("/hamilton")
        self
      end

      def has_greeting?(value)
        has_css?(".hamilton__greeting h1", text: "Hello #{value}", exact_text: true)
      end

      def open_docs
        find(".hamilton__nav a", text: "Documentation").click
      end

      def has_readme?
        has_css?(".hamilton__docs h1", text: "Hamilton", exact_text: true) &&
          has_css?(".hamilton__docs", text: "Hamilton adds a configurable greeting")
      end

      def open_guide
        find(".hamilton__docs a", text: "Hamilton guide").click
      end

      def has_guide?
        has_css?(".hamilton__docs h1", text: "Hamilton guide", exact_text: true)
      end
    end
  end
end

# frozen_string_literal: true

module PageObjects
  module Pages
    class Styleguide < PageObjects::Pages::Base
      def visit_index
        visit("/styleguide")
        self
      end

      # Not `has_title?`: Capybara already defines a `have_title` matcher for the document title,
      # and it would win over this one.
      def has_heading?(text)
        has_css?(".styleguide-contents .d-page-header__title", text: text)
      end

      def has_no_heading?(text)
        has_no_css?(".styleguide-contents .d-page-header__title", text: text)
      end

      def has_breadcrumb?(text)
        has_css?(".styleguide-contents .d-breadcrumbs__item", text: text)
      end

      # Scoped to the panel because these links get LinkTo's own `active` class rather than the
      # `--active` modifier the shared sidebar page object looks for.
      def has_active_nav_link?(text)
        has_css?(".sidebar-sections.styleguide-panel .sidebar-section-link.active", text: text)
      end

      COLOR_MODE_MENU = "styleguide-color-mode"

      def select_color_mode(mode)
        menu = PageObjects::Components::DMenu.new(".toggle-color-mode", COLOR_MODE_MENU)
        menu.expand
        menu.option(".toggle-color-mode__#{mode}-option").click

        # The menu content is portalled, and clicking an option tears it down. Waiting for that
        # to finish keeps a follow-up selection from clicking into a detached element.
        page.has_no_css?("#d-menu-portals [data-identifier='#{COLOR_MODE_MENU}']")
      end

      def has_color_mode?(mode)
        has_css?(".toggle-color-mode[data-current-mode='#{mode}']")
      end

      def has_no_color_selector?
        has_no_css?(".toggle-color-mode")
      end

      # Addressed by its visible title. Every example has one, but they are not unique across
      # every page — the forms section renders two examples titled "Input" — so a page with
      # duplicates needs a scoped lookup rather than this one, which would raise `Ambiguous`.
      def example(title)
        find("[data-test-example-title]", text: title, exact_text: true).ancestor(
          ".styleguide-example",
        )
      end

      # Found by accessible name rather than class, so a missing translation fails the test
      # instead of silently clicking a button labelled with the bracketed key.
      def example_source_toggle(title)
        example(title).find(:button, I18n.t("js.styleguide.example.toggle_code"))
      end

      def toggle_example_source(title)
        example_source_toggle(title).click
      end

      def has_example_source?(title, text:)
        example(title).has_css?(".styleguide-example__code", text: text)
      end

      # `visible: :all` on purpose: the source panel is meant to UNMOUNT, and a plain
      # `has_no_css?` would also pass for a CSS-hidden node, hiding that regression.
      def has_no_example_source?(title)
        example(title).has_no_css?(".styleguide-example__code", visible: :all)
      end

      # `expanded` is a boolean; it interpolates to the attribute's "true"/"false".
      def has_example_source_expanded?(title, expanded)
        example(title).has_css?(
          "button.styleguide-example__code-toggle[aria-expanded='#{expanded}']",
        )
      end

      # The toggle's `aria-controls` must name the revealed region, so the two are asserted
      # against each other rather than each against a hardcoded id.
      def has_example_source_wired?(title)
        card = example(title)
        # The attribute is part of the selector so Capybara waits for it, rather than reading it
        # once off a button that is present in both states.
        controls =
          card.find("button.styleguide-example__code-toggle[aria-controls]")["aria-controls"]
        controls.present? && card.has_css?(".styleguide-example__code##{controls}")
      end
    end
  end
end

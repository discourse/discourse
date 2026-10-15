# frozen_string_literal: true

module PageObjects
  module Components
    class ManageableRowListModal < PageObjects::Components::Base
      ROW = ".manageable-row-list__row"
      ENABLED_ROW = ".manageable-row-list__row.--enabled"

      def initialize(modal_selector, counter_i18n_key)
        super()
        @modal = modal_selector
        @counter_i18n_key = counter_i18n_key
      end

      def has_open?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(@modal).filter(visible: true),
        )
      end

      def has_closed?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(@modal).filter(visible: true),
        )
      end

      def search(query)
        browser_root
          .locator("#{@modal} .manageable-row-list__search-wrapper .filter-input")
          .filter(visible: true)
          .fill(query)
        self
      end

      def enabled_identifiers
        browser_root
          .locator("#{@modal} #{ENABLED_ROW}")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |el| row_key(el) }
      end

      def has_enabled_rows_in_order?(identifiers)
        PlaywrightMatchers.have_count(identifiers.size).matches?(
          browser_root.locator("#{@modal} #{ENABLED_ROW}").filter(visible: true),
        ) &&
          identifiers.each_with_index.all? do |identifier, index|
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator(
                "#{@modal} #{ENABLED_ROW}:nth-child(#{index + 1})[data-identifier='#{identifier}']",
              ).filter(visible: true),
            )
          end
      end

      def has_all_row?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@modal} #{ROW}[data-identifier='#{identifier}'], #{@modal} #{ROW}[data-reorderable-key='#{identifier}']",
          ).filter(visible: true),
        )
      end

      def has_no_all_row?(identifier)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "#{@modal} #{ROW}[data-identifier='#{identifier}'], #{@modal} #{ROW}[data-reorderable-key='#{identifier}']",
          ).filter(visible: true),
        )
      end

      def toggle(identifier)
        toggle_for(identifier).toggle
        self
      end

      def has_toggle_on?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@modal} #{ENABLED_ROW}[data-identifier='#{identifier}'], #{@modal} #{ENABLED_ROW}[data-reorderable-key='#{identifier}']",
          ).filter(visible: true),
        )
      end

      def has_toggle_off?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@modal} #{ROW}[data-identifier='#{identifier}'], #{@modal} #{ROW}[data-reorderable-key='#{identifier}']",
          ).filter(visible: true),
        ) &&
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(
              "#{@modal} #{ENABLED_ROW}[data-identifier='#{identifier}'], #{@modal} #{ENABLED_ROW}[data-reorderable-key='#{identifier}']",
            ).filter(visible: true),
          )
      end

      def toggle_for(identifier)
        PageObjects::Components::DToggleSwitch.new(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'] .d-toggle-switch__checkbox, " \
            "#{@modal} #{ROW}[data-reorderable-key='#{identifier}'] .d-toggle-switch__checkbox",
        )
      end

      def apply
        within_browser(@modal) do
          browser_root.locator("#{@modal}__apply").filter(visible: true).click
        end
        self
      end

      def close
        browser_root.locator("#{@modal} .d-modal__header .modal-close").filter(visible: true).click
        self
      end

      def move_up(identifier)
        browser_root
          .locator("#{@modal} #{ROW}[data-identifier='#{identifier}'] .d-icon-arrow-up")
          .filter(visible: true)
          .click
        self
      end

      def has_disabled_move_up?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@modal} #{ROW}[data-identifier='#{identifier}'] button.manageable-row-list__arrow[disabled] .d-icon-arrow-up",
          ).filter(visible: true),
        )
      end

      def has_disabled_move_down?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@modal} #{ROW}[data-identifier='#{identifier}'] button.manageable-row-list__arrow[disabled] .d-icon-arrow-down",
          ).filter(visible: true),
        )
      end

      def has_enabled_move_up?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@modal} #{ROW}[data-identifier='#{identifier}'] button.manageable-row-list__arrow:not([disabled]) .d-icon-arrow-up",
          ).filter(visible: true),
        )
      end

      def has_enabled_move_down?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@modal} #{ROW}[data-identifier='#{identifier}'] button.manageable-row-list__arrow:not([disabled]) .d-icon-arrow-down",
          ).filter(visible: true),
        )
      end

      def has_drag_controls?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@modal} .manageable-row-list__list.--reorderable").filter(
            visible: true,
          ),
        )
      end

      def has_no_drag_controls?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@modal} .manageable-row-list__list").filter(visible: true),
        ) &&
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator("#{@modal} .manageable-row-list__list.--reorderable").filter(
              visible: true,
            ),
          )
      end

      # Methods for when the enable_new_reordering_controls upcoming change is
      # enabled. The disabled group above keeps main's behaviour; anything whose
      # meaning differs is named separately rather than swapped in place.
      #
      # TODO (ui-kit-reorderable-list-cleanup) fold these over the disabled
      # group once the change ships.

      # The row's own reorderable list, for driving and inspecting its moves.
      def reorderable(identifier)
        PageObjects::Components::ReorderableList.new(reorderable_row_selector(identifier))
      end

      def has_move_up?(identifier)
        reorderable(identifier).has_destination?(:up)
      end

      def has_no_move_up?(identifier)
        reorderable(identifier).has_no_destination?(:up)
      end

      def has_move_down?(identifier)
        reorderable(identifier).has_destination?(:down)
      end

      def has_no_move_down?(identifier)
        reorderable(identifier).has_no_destination?(:down)
      end

      # Distinct from has_drag_controls?, which asks whether the legacy list is
      # in its reorderable state. This asks whether a row offers a handle.
      def has_reorderable_handles?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@modal} #{ROW} .d-reorderable-list__handle").filter(
            visible: true,
          ),
        )
      end

      def has_no_reorderable_handles?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@modal} #{ROW}").filter(visible: true),
        ) &&
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator("#{@modal} #{ROW} .d-reorderable-list__handle").filter(
              visible: true,
            ),
          )
      end

      # A real browser drag, which is the only way to prove the row is a
      # registered drag source rather than merely carrying a handle.
      def drag_report(source_identifier, target_identifier)
        drag_and_drop(
          source: "#{reorderable_row_selector(source_identifier)} .d-reorderable-list__handle",
          target: reorderable_row_selector(target_identifier),
          target_position: {
            x: 100,
            y: 1,
          },
        )
        self
      end

      def has_counter?(count, max)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t(@counter_i18n_key, count:, max:))],
          useInnerText: true,
        ).matches?(
          browser_root.locator("#{@modal} .manageable-row-list__counter").filter(visible: true),
        )
      end

      private

      # Either arm's row identity: the legacy rows name it one way, the shared
      # list names it another.
      def row_key(element)
        element.get_attribute("data-identifier") || element.get_attribute("data-reorderable-key")
      end

      def reorderable_row_selector(identifier)
        "#{@modal} #{ROW}[data-reorderable-key='#{identifier}']"
      end
    end
  end
end

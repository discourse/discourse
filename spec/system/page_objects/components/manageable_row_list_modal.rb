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
        has_css?(@modal)
      end

      def has_closed?
        has_no_css?(@modal)
      end

      def search(query)
        find("#{@modal} .manageable-row-list__search-wrapper .filter-input").set(query)
        self
      end

      def enabled_identifiers
        all("#{@modal} #{ENABLED_ROW}").map { |el| row_key(el) }
      end

      def has_all_row?(identifier)
        has_css?(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'], #{@modal} #{ROW}[data-reorderable-key='#{identifier}']",
        )
      end

      def has_no_all_row?(identifier)
        has_no_css?(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'], #{@modal} #{ROW}[data-reorderable-key='#{identifier}']",
        )
      end

      def toggle(identifier)
        toggle_for(identifier).toggle
        self
      end

      def has_toggle_on?(identifier)
        has_css?(
          "#{@modal} #{ENABLED_ROW}[data-identifier='#{identifier}'], #{@modal} #{ENABLED_ROW}[data-reorderable-key='#{identifier}']",
        )
      end

      def has_toggle_off?(identifier)
        has_css?(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'], #{@modal} #{ROW}[data-reorderable-key='#{identifier}']",
        ) &&
          has_no_css?(
            "#{@modal} #{ENABLED_ROW}[data-identifier='#{identifier}'], #{@modal} #{ENABLED_ROW}[data-reorderable-key='#{identifier}']",
          )
      end

      def toggle_for(identifier)
        PageObjects::Components::DToggleSwitch.new(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'], #{@modal} #{ROW}[data-reorderable-key='#{identifier}'] .d-toggle-switch__checkbox",
        )
      end

      def apply
        within(@modal) { find("#{@modal}__apply").click }
        self
      end

      def close
        find("#{@modal} .d-modal__header .modal-close").click
        self
      end

      def has_disabled_move_up?(identifier)
        has_css?(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'] button.manageable-row-list__arrow[disabled] .d-icon-arrow-up",
        )
      end

      def has_disabled_move_down?(identifier)
        has_css?(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'] button.manageable-row-list__arrow[disabled] .d-icon-arrow-down",
        )
      end

      def has_enabled_move_up?(identifier)
        has_css?(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'] button.manageable-row-list__arrow:not([disabled]) .d-icon-arrow-up",
        )
      end

      def has_enabled_move_down?(identifier)
        has_css?(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'] button.manageable-row-list__arrow:not([disabled]) .d-icon-arrow-down",
        )
      end

      def has_drag_controls?
        has_css?("#{@modal} .manageable-row-list__list.--reorderable")
      end

      def has_no_drag_controls?
        has_css?("#{@modal} .manageable-row-list__list") &&
          has_no_css?("#{@modal} .manageable-row-list__list.--reorderable")
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
        has_css?("#{@modal} #{ROW} .d-reorderable-list__handle")
      end

      def has_no_reorderable_handles?
        has_css?("#{@modal} #{ROW}") && has_no_css?("#{@modal} #{ROW} .d-reorderable-list__handle")
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
        has_css?(
          "#{@modal} .manageable-row-list__counter",
          text: I18n.t(@counter_i18n_key, count:, max:),
        )
      end

      private

      # Either arm's row identity: the legacy rows name it one way, the shared
      # list names it another.
      def row_key(element)
        element["data-identifier"] || element["data-reorderable-key"]
      end

      def reorderable_row_selector(identifier)
        "#{@modal} #{ROW}[data-reorderable-key='#{identifier}']"
      end
    end
  end
end

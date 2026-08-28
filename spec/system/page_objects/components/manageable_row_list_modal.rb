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
        all("#{@modal} #{ENABLED_ROW}").map { |el| el["data-identifier"] }
      end

      def has_all_row?(identifier)
        has_css?("#{@modal} #{ROW}[data-identifier='#{identifier}']")
      end

      def has_no_all_row?(identifier)
        has_no_css?("#{@modal} #{ROW}[data-identifier='#{identifier}']")
      end

      def toggle(identifier)
        toggle_for(identifier).toggle
        self
      end

      def has_toggle_on?(identifier)
        has_css?("#{@modal} #{ENABLED_ROW}[data-identifier='#{identifier}']")
      end

      def has_toggle_off?(identifier)
        has_css?("#{@modal} #{ROW}[data-identifier='#{identifier}']") &&
          has_no_css?("#{@modal} #{ENABLED_ROW}[data-identifier='#{identifier}']")
      end

      def toggle_for(identifier)
        PageObjects::Components::DToggleSwitch.new(
          "#{@modal} #{ROW}[data-identifier='#{identifier}'] .d-toggle-switch__checkbox",
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

      def drag_row(source_identifier, target_identifier)
        drag_and_drop(
          source: row_selector(source_identifier),
          source_position: {
            x: 32,
            y: 20,
          },
          target: row_selector(target_identifier),
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

      def row_selector(identifier)
        "#{@modal} #{ROW}[data-identifier='#{identifier}']"
      end
    end
  end
end

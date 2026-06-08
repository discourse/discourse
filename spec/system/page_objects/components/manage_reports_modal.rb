# frozen_string_literal: true

module PageObjects
  module Components
    class ManageReportsModal < PageObjects::Components::Base
      MODAL = ".manage-reports"
      ROW = ".manage-reports__row"
      ENABLED_ROW = ".manage-reports__row.--enabled"

      def has_open?
        has_css?(MODAL)
      end

      def has_closed?
        has_no_css?(MODAL)
      end

      def search(query)
        find("#{MODAL} .manage-reports__search-wrapper .filter-input").set(query)
        self
      end

      def enabled_identifiers
        all("#{MODAL} #{ENABLED_ROW}").map { |el| el["data-identifier"] }
      end

      def has_all_row?(identifier)
        has_css?("#{MODAL} #{ROW}[data-identifier='#{identifier}']")
      end

      def has_no_all_row?(identifier)
        has_no_css?("#{MODAL} #{ROW}[data-identifier='#{identifier}']")
      end

      def toggle(identifier)
        toggle_for(identifier).toggle
        self
      end

      def has_toggle_on?(identifier)
        has_css?("#{MODAL} #{ENABLED_ROW}[data-identifier='#{identifier}']")
      end

      def has_toggle_off?(identifier)
        has_css?("#{MODAL} #{ROW}[data-identifier='#{identifier}']") &&
          has_no_css?("#{MODAL} #{ENABLED_ROW}[data-identifier='#{identifier}']")
      end

      def toggle_for(identifier)
        PageObjects::Components::DToggleSwitch.new(
          "#{MODAL} #{ROW}[data-identifier='#{identifier}'] .d-toggle-switch__checkbox",
        )
      end

      def apply
        within(MODAL) { find(".manage-reports__apply").click }
        self
      end

      def close
        find("#{MODAL} .d-modal__header .modal-close").click
        self
      end

      def has_disabled_move_up?(identifier)
        has_css?(
          "#{MODAL} #{ROW}[data-identifier='#{identifier}'] button.manage-reports__arrow[disabled] .d-icon-arrow-up",
        )
      end

      def has_disabled_move_down?(identifier)
        has_css?(
          "#{MODAL} #{ROW}[data-identifier='#{identifier}'] button.manage-reports__arrow[disabled] .d-icon-arrow-down",
        )
      end

      def has_enabled_move_up?(identifier)
        has_css?(
          "#{MODAL} #{ROW}[data-identifier='#{identifier}'] button.manage-reports__arrow:not([disabled]) .d-icon-arrow-up",
        )
      end

      def has_enabled_move_down?(identifier)
        has_css?(
          "#{MODAL} #{ROW}[data-identifier='#{identifier}'] button.manage-reports__arrow:not([disabled]) .d-icon-arrow-down",
        )
      end

      def has_drag_controls?
        has_css?("#{MODAL} .manage-reports__list.--reorderable")
      end

      def has_no_drag_controls?
        has_css?("#{MODAL} .manage-reports__list") &&
          has_no_css?("#{MODAL} .manage-reports__list.--reorderable")
      end

      def has_counter?(count, max)
        has_css?(
          "#{MODAL} .manage-reports__counter",
          text: I18n.t("admin_js.admin.dashboard.reports_section.modal.counter", count:, max:),
        )
      end
    end
  end
end

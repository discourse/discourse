# frozen_string_literal: true

module PageObjects
  module Components
    class ManageReportsModal < PageObjects::Components::Base
      MODAL = ".manage-reports-modal"

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
        within("#{MODAL} .manage-reports__list--enabled") do
          all(".manage-reports__row").map { |el| el["data-identifier"] }
        end
      end

      def all_identifiers
        within("#{MODAL} .manage-reports__list--all") do
          all(".manage-reports__row").map { |el| el["data-identifier"] }
        end
      end

      def has_all_row?(identifier)
        has_css?(
          "#{MODAL} .manage-reports__list--all " \
            ".manage-reports__row[data-identifier='#{identifier}']",
        )
      end

      def has_no_all_row?(identifier)
        has_no_css?(
          "#{MODAL} .manage-reports__list--all " \
            ".manage-reports__row[data-identifier='#{identifier}']",
        )
      end

      def toggle(identifier)
        toggle_for(identifier).toggle
        self
      end

      def has_toggle_on?(identifier)
        has_css?(
          "#{MODAL} .manage-reports__list--enabled " \
            ".manage-reports__row[data-identifier='#{identifier}']",
        )
      end

      def has_toggle_off?(identifier)
        has_no_css?(
          "#{MODAL} .manage-reports__list--enabled " \
            ".manage-reports__row[data-identifier='#{identifier}']",
        ) &&
          has_css?(
            "#{MODAL} .manage-reports__list--all " \
              ".manage-reports__row[data-identifier='#{identifier}']",
          )
      end

      def toggle_for(identifier)
        enabled_row =
          "#{MODAL} .manage-reports__list--enabled " \
            ".manage-reports__row[data-identifier='#{identifier}']"
        toggle_selector =
          if has_css?(enabled_row, wait: 0)
            "#{enabled_row} .d-toggle-switch__checkbox"
          else
            "#{MODAL} .manage-reports__list--all " \
              ".manage-reports__row[data-identifier='#{identifier}'] " \
              ".d-toggle-switch__checkbox"
          end
        PageObjects::Components::DToggleSwitch.new(toggle_selector)
      end

      def apply
        within(MODAL) { find(".manage-reports__apply").click }
        self
      end

      def close
        find("#{MODAL} .d-modal__header .modal-close").click
        self
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

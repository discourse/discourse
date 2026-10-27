# frozen_string_literal: true

module PageObjects
  module Modals
    class RecalculateScoresForm < PageObjects::Modals::Base
      def form
        PageObjects::Components::FormKit.new(".recalculate-scores-form")
      end

      def select_update_range(range)
        form.field("range").select(range)
      end

      def date_range
        form.field("range").component.find(".form-kit__container-description")
      end

      def has_no_date_range?
        form.field("range").component.has_no_css?(".form-kit__container-description")
      end

      def fill_since_date(since)
        form.field("from_date").fill_in(since)
      end

      def has_since_date_field?
        form.has_field_with_name?("from_date")
      end

      def has_no_since_date_field?
        form.has_no_field_with_name?("from_date")
      end

      def status
        find(".recalculate-modal__status")
      end

      def remaining
        find(".recalculate-modal__footer-text")
      end

      def submit_button
        find(".recalculate-modal__submit")
      end

      def has_disabled_submit_button?
        has_css?(".recalculate-modal__submit[disabled]")
      end
    end
  end
end

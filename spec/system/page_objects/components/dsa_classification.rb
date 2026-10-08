# frozen_string_literal: true
module PageObjects
  module Components
    class DsaClassification < PageObjects::Components::Base
      def has_classification_form?
        has_css?(".review-item__aside .dsa-classification", text: "Community rule") &&
          has_select?("Community rule") && has_select?("Category") &&
          has_css?(".dsa-classification select", count: 2) &&
          has_no_css?(".dsa-classification textarea")
      end

      def has_no_classification_form?
        has_no_css?(".dsa-classification")
      end

      def classify(community_rule:, category:)
        within(".dsa-classification") do
          select(community_rule, from: "Community rule")
          select(category, from: "Category")
          click_button("Save classification")
        end
      end

      def has_timeline_focus?
        has_css?(".review-item .timeline a:focus")
      end

      def has_completion_note?(community_rule:, category:)
        has_css?(".timeline-event", text: "DSA classification") &&
          has_css?(".timeline-event", text: community_rule) &&
          has_css?(".timeline-event", text: category)
      end

      def visit_unfinished
        page.visit("/review")
        within(".reviewable-filter:first-child") do
          PageObjects::Components::SelectKit.new(".select-kit").select_row_by_name(
            "Needs DSA classification",
          )
        end
        click_button("Refresh")
        self
      end

      def has_unfinished_reviewable?(reviewable)
        has_css?(
          ".review-item[data-reviewable-id='#{reviewable.id}']",
          text: "Needs DSA classification",
        )
      end

      def has_illegal_reporting_link?(url)
        has_css?(".flag-modal .d-modal__footer a[href='#{url}']", text: "this form") &&
          has_text?("To report potentially illegal content")
      end

      def open_illegal_reporting_form
        within(".flag-modal .d-modal__footer") { click_link("this form") }
      end

      def has_no_illegal_flag?
        has_no_css?("#radio_illegal", visible: :all)
      end
    end
  end
end

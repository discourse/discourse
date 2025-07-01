# frozen_string_literal: true

module PageObjects
  module Pages
    class Reviewable < PageObjects::Pages::Base
      def visit(reviewable)
        page.visit("/review/#{reviewable.id}")
        self
      end

      def has_spam_flag_reason?(reviewable, count: 1)
        has_flag_reason?(reviewable, css_class: "spam", type: :spam, count:)
      end

      def has_off_topic_flag_reason?(reviewable, count: 1)
        has_flag_reason?(reviewable, css_class: "off-topic", type: :off_topic, count:)
      end

      def has_illegal_flag_reason?(reviewable, count: 1)
        has_flag_reason?(reviewable, css_class: "illegal", type: :illegal, count:)
      end

      def has_inappropriate_flag_reason?(reviewable, count: 1)
        has_flag_reason?(reviewable, css_class: "inappropriate", type: :inappropriate, count:)
      end

      def has_needs_approval_flag_reason?(reviewable, count: 1)
        has_flag_reason?(reviewable, css_class: "needs-approval", type: :needs_approval, count:)
      end

      private

      def has_flag_reason?(reviewable, css_class:, type:, count: 1)
        within_reviewable_item(reviewable) do
          expect(find(".review-item__flag-reason.--#{css_class}").text.gsub(/\s+/, " ")).to eq(
            "#{count} #{ReviewableScore.type_title(type)}",
          )

          expect(page).to have_css(".review-item__flag-count.--#{css_class}")
        end
      end

      def within_reviewable_item(reviewable)
        within(".review-item[data-reviewable-id='#{reviewable.id}']") { yield }
      end
    end
  end
end

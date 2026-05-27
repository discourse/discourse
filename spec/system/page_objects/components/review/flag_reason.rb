# frozen_string_literal: true

module PageObjects
  module Components
    module Review
      class FlagReason < PageObjects::Components::Base
        def has_spam_flag_reason?(reviewable, count: 1)
          has_flag_reason?(reviewable, type: :spam, count:)
        end

        def has_off_topic_flag_reason?(reviewable, count: 1)
          has_flag_reason?(reviewable, type: :off_topic, count:)
        end

        def has_illegal_flag_reason?(reviewable, count: 1)
          has_flag_reason?(reviewable, type: :illegal, count:)
        end

        def has_inappropriate_flag_reason?(reviewable, count: 1)
          has_flag_reason?(reviewable, type: :inappropriate, count:)
        end

        def has_needs_approval_flag_reason?(reviewable, count: 1)
          has_flag_reason?(reviewable, type: :needs_approval, count:)
        end

        private

        def has_flag_reason?(reviewable, type:, count: 1)
          within_reviewable_item(reviewable) do
            expected_text =
              if count > 1
                "#{ReviewableScore.type_title(type)} x#{count}"
              else
                ReviewableScore.type_title(type).to_s
              end

            within(".review-item__header") do
              flag_reason_element =
                find(".review-item__flag-reason", text: ReviewableScore.type_title(type))
              expect(flag_reason_element.text.gsub(/\s+/, " ")).to eq(expected_text)

              if count > 1
                expect(flag_reason_element).to have_css(".review-item__flag-count")
              else
                expect(flag_reason_element).to have_no_css(".review-item__flag-count")
              end
            end
          end
        end

        def within_reviewable_item(reviewable)
          within(".review-item[data-reviewable-id='#{reviewable.id}']") { yield }
        end
      end
    end
  end
end

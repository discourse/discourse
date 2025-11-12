# frozen_string_literal: true

module PageObjects
  module Components
    module Review
      class FlagReason < PageObjects::Components::Base
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
            expected_text =
              if count > 1
                "#{ReviewableScore.type_title(type)} x#{count}"
              else
                ReviewableScore.type_title(type).to_s
              end

            within(".review-item__header") do
              expect(find(".review-item__flag-reason.--#{css_class}").text.gsub(/\s+/, " ")).to eq(
                expected_text,
              )

              if count > 1
                expect(page).to have_css(".review-item__flag-count.--#{css_class}")
              else
                expect(page).to have_no_css(".review-item__flag-count.--#{css_class}")
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

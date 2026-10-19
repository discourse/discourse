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

            within_browser(browser_root.locator(".review-item__header").filter(visible: true)) do
              flag_reason_element =
                browser_root
                  .locator(".review-item__flag-reason")
                  .filter(visible: true)
                  .filter(hasText: browser_text_pattern(ReviewableScore.type_title(type)))
              expect(flag_reason_element.inner_text.strip.gsub(/\s+/, " ")).to eq(expected_text)

              if count > 1
                expect(
                  flag_reason_element.locator(".review-item__flag-count").filter(visible: true),
                ).not_to have_count(0)
              else
                expect(
                  flag_reason_element
                    .tap do |parent|
                      parent.wait_for(
                        state: "visible",
                        timeout: Capybara.default_max_wait_time * 1000,
                      )
                    end
                    .locator(".review-item__flag-count")
                    .filter(visible: true),
                ).to have_count(0)
              end
            end
          end
        end

        def within_reviewable_item(reviewable)
          within_browser(
            browser_root.locator(".review-item[data-reviewable-id='#{reviewable.id}']").filter(
              visible: true,
            ),
          ) { yield }
        end
      end
    end
  end
end

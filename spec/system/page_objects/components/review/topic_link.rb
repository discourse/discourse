# frozen_string_literal: true

module PageObjects
  module Components
    module Review
      class TopicLink < PageObjects::Components::Base
        WRAPPER_CSS = ".review-item__meta-topic-title"

        def has_closed_topic_status?
          within_browser(WRAPPER_CSS) do
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator(".topic-status [class*='d-icon-lock']").filter(visible: true),
            )
          end
        end

        def has_topic_link?(topic_title:, post_url:)
          within_browser(WRAPPER_CSS) do
            expect(
              browser_root
                .get_by_role("link")
                .and(
                  browser_root.locator(
                    "[id=#{topic_title.to_s.to_json}], [name=#{topic_title.to_s.to_json}]",
                  ).or(browser_root.get_by_role("link", name: topic_title)),
                )
                .and(browser_root.locator("[href=#{post_url.to_s.to_json}]"))
                .filter(visible: true),
            ).not_to PlaywrightMatchers.have_count(0)
          end
        end

        def has_category_badge?(category_name)
          within_browser(WRAPPER_CSS) do
            expect(
              browser_root.locator(".badge-category__name").filter(visible: true),
            ).to PlaywrightMatchers.contain_text(
              [browser_text_pattern(category_name)],
              useInnerText: true,
            )
          end
        end

        def has_tag_link?(tag_name:, tag_url:)
          within_browser(WRAPPER_CSS) do
            expect(
              browser_root
                .get_by_role("link")
                .and(
                  browser_root.locator(
                    "[id=#{tag_name.to_s.to_json}], [name=#{tag_name.to_s.to_json}]",
                  ).or(browser_root.get_by_role("link", name: tag_name)),
                )
                .and(browser_root.locator("[href=#{tag_url.to_s.to_json}]"))
                .filter(visible: true),
            ).not_to PlaywrightMatchers.have_count(0)
          end
        end
      end
    end
  end
end

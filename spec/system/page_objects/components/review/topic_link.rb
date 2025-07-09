# frozen_string_literal: true

module PageObjects
  module Components
    module Review
      class TopicLink < PageObjects::Components::Base
        WRAPPER_CSS = ".post-topic"

        def has_closed_topic_status?
          within(WRAPPER_CSS) { has_css?(".topic-status [class*='.d-icon-topic.closed']") }
        end

        def has_topic_link?(topic_title:, post_url:)
          within(WRAPPER_CSS) { expect(page).to have_link(topic_title, href: post_url) }
        end

        def has_category_badge?(category_name)
          within(WRAPPER_CSS) do
            expect(page).to have_css(".badge-category__name", text: category_name)
          end
        end

        def has_tag_link?(tag_name:, tag_url:)
          within(WRAPPER_CSS) { expect(page).to have_link(tag_name, href: tag_url) }
        end
      end
    end
  end
end

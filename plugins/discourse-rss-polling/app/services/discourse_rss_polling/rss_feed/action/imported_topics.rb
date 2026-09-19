# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    module Action
      class ImportedTopics < Service::ActionBase
        option :feed_items

        def call
          topic_urls = topic_urls_by_key(feed_items.map(&:url))
          feed_items.index_with { |feed_item| topic_urls[embed_key(feed_item.url)] }.compact
        end

        private

        def topic_urls_by_key(urls)
          urls = urls.compact_blank.uniq
          return {} if urls.empty?

          TopicEmbed
            .with_embed_urls(urls)
            .select(:id, :embed_url, :topic_id)
            .order(:id)
            .includes(:topic)
            .each_with_object({}) do |embed, topic_urls|
              next if embed.topic.nil?

              topic_urls[embed_key(embed.embed_url)] ||= embed.topic.relative_url
            end
        end

        def embed_key(url)
          return if url.blank?

          TopicEmbed.embed_url_key(url)
        end
      end
    end
  end
end

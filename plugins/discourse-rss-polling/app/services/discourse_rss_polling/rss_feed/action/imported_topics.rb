# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    module Action
      class ImportedTopics < Service::ActionBase
        option :feed_items

        def call
          keys = feed_items.index_with { |feed_item| embed_key(feed_item.url) }
          topic_urls = topic_urls_by_key(keys.values)

          keys.each_with_object({}) do |(feed_item, key), imported|
            imported[feed_item] = topic_urls[key] if key && topic_urls.key?(key)
          end
        end

        private

        def topic_urls_by_key(keys)
          keys = keys.compact.uniq
          return {} if keys.empty?

          patterns = keys.map { |key| "^https?://#{Regexp.escape(key)}$" }

          TopicEmbed
            .where("embed_url ~* ANY(ARRAY[?])", patterns)
            .includes(:topic)
            .each_with_object({}) do |embed, topic_urls|
              next if embed.topic.nil?

              topic_urls[embed_key(embed.embed_url)] ||= embed.topic.relative_url
            end
        end

        def embed_key(url)
          return if url.blank?

          TopicEmbed.normalize_url(url).sub(%r{\Ahttps?://}, "")
        end
      end
    end
  end
end

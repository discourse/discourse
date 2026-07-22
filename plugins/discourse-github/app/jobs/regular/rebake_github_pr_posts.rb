# frozen_string_literal: true

module Jobs
  class RebakeGithubPrPosts < ::Jobs::Base
    sidekiq_options queue: "low"

    PR_PATH = %r{\A/[^/]+/[^/]+/pull/\d+\z}

    def execute(args)
      url = args[:pr_url]
      return unless pr_path(url)

      rebake_posts(url)
      rebake_chat_messages(url) if SiteSetting.chat_enabled
    end

    private

    def pr_path(url)
      path = URI(url.to_s).path
      path if path&.match?(PR_PATH)
    rescue URI::InvalidURIError
      nil
    end

    # tolerates scheme/host variants (http, www) the onebox engine accepts
    def pr_url_pattern(url)
      "https?://(www\\.)?github\\.com#{Regexp.escape(pr_path(url))}"
    end

    # anchored so /pull/12 does not match /pull/123
    def pr_links(relation, url)
      relation.where("url ~* ?", "^#{pr_url_pattern(url)}([/?#].*)?$")
    end

    # oneboxes are cached per exact URL - raw for inline, normalized for full
    def invalidate_onebox_caches(urls)
      urls
        .flat_map { |url| [url, normalized(url)] }
        .compact
        .uniq
        .each do |url|
          Oneboxer.invalidate(url)
          InlineOneboxer.invalidate(url)
        end
    end

    def normalized(url)
      UrlHelper.normalized_encode(url).to_s
    rescue StandardError
      nil
    end

    def rebake_posts(url)
      rows = pr_links(TopicLink, url).distinct.pluck(:url, :post_id)
      invalidate_onebox_caches(rows.map(&:first).uniq)

      Post
        .where(id: rows.map(&:last).uniq)
        .where(
          "cooked ~* :pattern AND (cooked LIKE '%githubpullrequest%' OR cooked LIKE '%inline-onebox%')",
          pattern: pr_url_pattern(url),
        )
        .find_each { |post| post.rebake!(priority: :low, skip_publish_rebaked_changes: true) }
    end

    def rebake_chat_messages(url)
      rows = pr_links(::Chat::MessageLink, url).distinct.pluck(:url, :chat_message_id)
      invalidate_onebox_caches(rows.map(&:first).uniq)

      ::Chat::Message
        .where(id: rows.map(&:last).uniq)
        .where(
          "cooked ~* :pattern AND (cooked LIKE '%githubpullrequest%' OR cooked LIKE '%inline-onebox%')",
          pattern: pr_url_pattern(url),
        )
        .find_each { |message| message.rebake!(priority: :low, skip_notifications: true) }
    end
  end
end

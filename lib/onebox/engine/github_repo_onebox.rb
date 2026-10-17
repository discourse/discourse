# frozen_string_literal: true

require_relative "../mixins/github_body"
require_relative "../mixins/github_api"

module Onebox
  module Engine
    class GithubRepoOnebox
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubApi

      matches_domain("github.com", "www.github.com")
      always_https

      def self.matches_path(path)
        path.match?(%r{^/[^/]+/[^/]+/?$})
      end

      def url
        "https://api.github.com/repos/#{match[:org]}/#{match[:repository]}"
      end

      def inline_data
        return unless github_token?

        result = raw
        title = "GitHub - #{result["full_name"]}"
        title += " - #{Onebox::Helpers.truncate(result["description"])}" if result[
          "description"
        ].present?
        { title: title }
      rescue StandardError => e
        Rails.logger.warn("Inline GitHub repo onebox error for #{@url}: #{e.message}")
        nil
      end

      private

      def match
        @match ||= @url.match(%r{github\.com/(?<org>[^/]+)/(?<repository>[^/]+)})
      end

      def data
        result = raw.clone
        result["link"] = link
        description = result["description"]
        title = "GitHub - #{result["full_name"]}"

        if description.blank?
          description = I18n.t("onebox.github.no_description", repo: result["full_name"])
        else
          title += ": #{Onebox::Helpers.truncate(description)}"
        end

        result["description"] = description
        result["title"] = title
        result["is_private"] = result["private"]
        result["language"] = result["language"].presence
        result["stars"] = repository_count("stars", result["stargazers_count"])
        result["forks"] = repository_count("forks", result["forks_count"])
        result["has_metadata"] = result["language"].present? || result["stars"].present? ||
          result["forks"].present?
        snapshot_at = Time.now.utc
        result["snapshot_at"] = snapshot_at.strftime("%I:%M%p - %d %b %y %Z")
        result["snapshot_at_date"] = snapshot_at.strftime("%F")
        result["snapshot_at_time"] = snapshot_at.strftime("%T")
        result["i18n"] = { snapshot: I18n.t("onebox.github.snapshot") }

        # The SecureRandom part of this doesn't matter, it's just used for caching the
        # repo thumbnail which is generated on the fly by GitHub. There isn't detail
        # in https://github.blog/2021-06-22-framework-building-open-graph-images/,
        # but this SO answer https://stackoverflow.com/a/69043743 suggests this is
        # how it works and testing confirms it.
        result[
          "thumbnail"
        ] = "https://opengraph.githubassets.com/#{SecureRandom.hex}/#{match[:org]}/#{match[:repository]}"
        result
      end

      def repository_count(key, count)
        return unless count.to_i.positive?

        I18n.t("onebox.github.#{key}", count: count, number: compact_repository_count(count))
      end

      def compact_repository_count(count)
        return count.to_s if count < 1000

        # Promote counts that would round to 1000.0k to the next unit.
        divisor, unit = count.round(-2) >= 1_000_000 ? [1_000_000, "millions"] : [1000, "thousands"]
        number =
          ActiveSupport::NumberHelper.number_to_rounded(
            count.to_f / divisor,
            precision: 1,
            significant: false,
            strip_insignificant_zeros: false,
            separator: I18n.t("js.number.format.separator"),
            delimiter: "",
          )

        I18n.t("js.number.short.#{unit}", number: number)
      end
    end
  end
end

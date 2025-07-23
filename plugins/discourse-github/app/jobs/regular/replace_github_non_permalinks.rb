# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Jobs
  class ReplaceGithubNonPermalinks < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      return unless SiteSetting.enable_discourse_github_plugin?
      return unless SiteSetting.github_permalinks_enabled?

      post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) if post_id.blank?

      post = Post.find_by(id: post_id)
      return if post.blank?

      raw = post.raw.dup
      start_raw = raw.dup

      regex =
        %r{github\.com/(?<user>[^/]+)/(?<repo>[^/\s]+)/blob/(?<sha1>[^/\s]+)/(?<file>[^#\s]+)(?<from-to>#(L([^-\s]*)(-L(\d*))?))?}i

      matches = post.raw.scan(regex)
      matches.each do |user, repo, sha1, file, from_to|
        next if excluded?(user, repo, file)

        begin
          api_url = "https://api.github.com/repos/#{user}/#{repo}/commits/#{sha1}"
          json = api_request(api_url)
          if json && (json["sha"] != sha1)
            new_sha = json["sha"]
            old_url = "github.com/#{user}/#{repo}/blob/#{sha1}/#{file}#{from_to}"
            new_url = "github.com/#{user}/#{repo}/blob/#{new_sha}/#{file}#{from_to}"
            raw.sub!(old_url, new_url)
          end
        rescue => e
          log(
            :error,
            "Failed to replace Github link with permalink in post #{post_id}\n" + e.message + "\n" +
              e.backtrace.join("\n"),
          )
        end
      end

      post.reload

      if start_raw == post.raw && raw != post.raw
        changes = { raw: raw, edit_reason: I18n.t("replace_github_link.edit_reason") }
        post.revise(Discourse.system_user, changes, bypass_bump: true)
      end
    end

    def excluded?(user, repo, file)
      excluded = SiteSetting.github_permalinks_exclude.split("|")

      excluded.each do |e|
        path_parts = e.split("/")
        # when only filename is provided
        if path_parts.length == 1
          return true if file == e
          next
        end

        path_parts.each { |p| p.sub!("*", "\\S+") }

        regex = Regexp.new(path_parts.join("\/"))
        return true if "#{user}/#{repo}/#{file}".match(regex)
      end

      false
    end

    private

    def api_request(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      JSON.parse(response.body) if response.kind_of? Net::HTTPSuccess
    end

    def log(log_level, message)
      Rails.logger.public_send(
        log_level,
        "#{RailsMultisite::ConnectionManagement.current_db}: #{message}",
      )
    end
  end
end

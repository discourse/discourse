# frozen_string_literal: true

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

      client = Discourse::GithubApi.for(token: SiteSetting.github_linkback_access_token)
      return if client.backing_off?

      raw = post.raw.dup
      start_raw = raw.dup

      regex =
        %r{github\.com/(?<user>[^/]+)/(?<repo>[^/\s]+)/blob/(?<sha1>[^/\s]+)/(?<file>[^#\s]+)(?<from-to>#(L([^-\s]*)(-L(\d*))?))?}i

      matches = post.raw.scan(regex)
      matches.each do |user, repo, sha1, file, from_to|
        next if excluded?(user, repo, file)

        begin
          commit = client.get("/repos/#{user}/#{repo}/commits/#{sha1}")
          if commit && commit["sha"] != sha1
            new_sha = commit["sha"]
            old_url = "github.com/#{user}/#{repo}/blob/#{sha1}/#{file}#{from_to}"
            new_url = "github.com/#{user}/#{repo}/blob/#{new_sha}/#{file}#{from_to}"
            raw.sub!(old_url, new_url)
          end
        rescue Discourse::GithubApi::NotFound
          next
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

    def log(log_level, message)
      Rails.logger.public_send(
        log_level,
        "#{RailsMultisite::ConnectionManagement.current_db}: #{message}",
      )
    end
  end
end

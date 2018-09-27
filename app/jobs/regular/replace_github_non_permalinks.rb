require 'net/http'
require 'json'
require 'uri'

module Jobs

  class ReplaceGithubNonPermalinks < Jobs::Base
    sidekiq_options queue: 'low'

    def execute(args)
      post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) unless post_id.present?

      post = Post.find_by(id: post_id)
      return unless post.present?

      raw = post.raw.dup
      start_raw = raw.dup

      regex = /github\.com\/(?<user>[^\/]+)\/(?<repo>[^\/\s]+)\/blob\/(?<sha1>[^\/\s]+)\/(?<file>[^#\s]+)(?<from-to>#(L([^-\s]*)(-L(\d*))?))?/i

      matches = post.raw.scan(regex)
      matches.each do |url|
        user = url[0]
        repo = url[1]
        sha1 = url[2]
        file = url[3]
        from_to = url[4]

        begin
          url = "https://api.github.com/repos/#{user}/#{repo}/commits/#{sha1}"
          json = api_request(url)
          if json && (json["sha"] != sha1)
            new_sha = json["sha"]
            url = "github.com/#{user}/#{repo}/blob/#{new_sha}/#{file}#{from_to}"
            raw.sub!(regex, url)
          end
        rescue => e
          log(:error, "Failed to replace Github link with permalink in post #{post_id}\n" + e.message + "\n" + e.backtrace.join("\n"))
        end
      end

      post.reload

      if start_raw == post.raw && raw != post.raw
        changes = { raw: raw, edit_reason: I18n.t("replace_github_link.edit_reason") }
        post.revise(Discourse.system_user, changes, bypass_bump: true)
      end
    end

    private

    def api_request(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.kind_of? Net::HTTPSuccess
        return JSON.parse(response.body)
      end
    end

    def log(log_level, message)
      Rails.logger.public_send(
        log_level,
        "#{RailsMultisite::ConnectionManagement.current_db}: #{message}"
      )
    end
  end
end

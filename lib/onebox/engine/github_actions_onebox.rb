# frozen_string_literal: true

require_relative "../mixins/github_body"
require_relative "../mixins/github_auth_header"

module Onebox
  module Engine
    class GithubActionsOnebox
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubAuthHeader

      matches_regexp(
        %r{^https?://(?:www\.)?(?:(?:\w)+\.)?github\.com/(?<org>.+)/(?<repo>.+)/(actions/runs/[[:digit:]]+|pull/[[:digit:]]*/checks\?check_run_id=[[:digit:]]+)},
      )
      always_https

      def url
        if type == :actions_run
          "https://api.github.com/repos/#{match[:org]}/#{match[:repo]}/actions/runs/#{match[:run_id]}"
        elsif type == :pr_run
          "https://api.github.com/repos/#{match[:org]}/#{match[:repo]}/check-runs/#{match[:check_run_id]}"
        end
      end

      def self.priority
        90 # overlaps with GithubPullRequestOnebox
      end

      private

      def match_url
        return if defined?(@match) && defined?(@type)

        if match =
             @url.match(
               %r{^https?://(?:www\.)?(?:(?:\w)+\.)?github\.com/(?<org>.+)/(?<repo>.+)/actions/runs/(?<run_id>[[:digit:]]+)},
             )
          @match = match
          @type = :actions_run
        end

        if match =
             @url.match(
               %r{^https?://(?:www\.)?(?:(?:\w)+\.)?github\.com/(?<org>.+)/(?<repo>.+)/pull/(?<pr_id>[[:digit:]]*)/checks\?check_run_id=(?<check_run_id>[[:digit:]]+)},
             )
          @match = match
          @type = :pr_run
        end
      end

      def match
        return @match if defined?(@match)

        match_url
        @match
      end

      def type
        return @type if defined?(@type)

        match_url
        @type
      end

      def data
        result = raw(github_auth_header(match[:org])).clone

        status = "unknown"
        if result["status"] == "completed"
          if result["conclusion"] == "success"
            status = "success"
          elsif result["conclusion"] == "failure"
            status = "failure"
          end
        elsif result["status"] == "in_progress"
          status = "pending"
        end

        title =
          if type == :actions_run
            result["head_commit"]["message"].lines.first
          elsif type == :pr_run
            pr_url =
              "https://api.github.com/repos/#{match[:org]}/#{match[:repo]}/pulls/#{match[:pr_id]}"
            ::MultiJson.load(URI.parse(pr_url).open(read_timeout: timeout))["title"]
          end

        {
          :link => @url,
          :title => title,
          :name => result["name"],
          :run_number => result["run_number"],
          status => true,
        }
      end
    end
  end
end

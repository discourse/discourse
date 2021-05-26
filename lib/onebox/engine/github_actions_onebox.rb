# frozen_string_literal: true

require_relative '../mixins/github_body'

module Onebox
  module Engine
    class GithubActionsOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_regexp(/^https?:\/\/(?:www\.)?(?:(?:\w)+\.)?github\.com\/(?<org>.+)\/(?<repo>.+)\/actions\/runs\/(?<run_id>[[:digit:]]+)/)
      always_https

      def url
        "https://api.github.com/repos/#{match[:org]}/#{match[:repo]}/actions/runs/#{match[:run_id]}"
      end

      private

      def match
        @match ||= @url.match(/^https?:\/\/(?:www\.)?(?:(?:\w)+\.)?github\.com\/(?<org>.+)\/(?<repo>.+)\/actions\/runs\/(?<run_id>[[:digit:]]+)/)
      end

      def data
        status = "unknown"
        if raw["status"] == "completed"
          if raw["conclusion"] == "success"
            status = "success"
          elsif raw["conclusion"] == "failure"
            status = "failure"
          elsif raw["conclusion"] == "cancelled"
          end
        elsif raw["status"] == "in_progress"
          status = "pending"
        end

        {
          link: @url,
          title: raw["head_commit"]["message"].lines.first,
          name: raw["name"],
          run_number: raw["run_number"],
          status => true,
        }
      end
    end
  end
end

# frozen_string_literal: true

module PageObjects
  module Components
    class GithubOnebox < PageObjects::Components::Base
      def has_status?(status)
        page.has_css?(".github-pr-status", exact_text: I18n.t("onebox.github.pr_status.#{status}"))
      end

      def has_no_large_pr_icons?
        page.has_no_css?(".githubpullrequest .github-icon-container")
      end
    end
  end
end

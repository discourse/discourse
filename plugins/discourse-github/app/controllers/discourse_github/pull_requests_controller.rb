# frozen_string_literal: true

module DiscourseGithub
  class PullRequestsController < ::ApplicationController
    requires_plugin "discourse-github"

    def status
      owner = params[:owner]
      repo = params[:repo]
      number = params[:number]

      if owner.blank? || repo.blank? || number.blank?
        return(
          render json: {
                   error: I18n.t("discourse_github.errors.missing_parameters"),
                 },
                 status: :bad_request
        )
      end

      if state = GithubPrStatus.fetch(owner, repo, number)
        render json: { state: state }
      else
        render json: {
                 error: I18n.t("discourse_github.errors.failed_to_fetch_pr_status"),
               },
               status: :bad_gateway
      end
    end
  end
end

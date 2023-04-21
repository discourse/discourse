# frozen_string_literal: true

class RemoteThemeSerializer < ApplicationSerializer
  attributes :id,
             :remote_url,
             :remote_version,
             :local_version,
             :commits_behind,
             :branch,
             :remote_updated_at,
             :updated_at,
             :github_diff_link,
             :last_error_text,
             :is_git?,
             :license_url,
             :about_url,
             :authors,
             :theme_version,
             :minimum_discourse_version,
             :maximum_discourse_version

  # wow, AMS has some pretty nutty logic where it tries to find the path here
  # from action dispatch, tell it not to
  def about_url
    object.about_url
  end

  def include_github_diff_link?
    github_diff_link.present?
  end
end

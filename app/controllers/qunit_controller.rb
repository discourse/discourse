# frozen_string_literal: true

class QunitController < ApplicationController
  # Same list maintained in discourse-test-load-dynamic-js.js
  ALWAYS_LOADED_PLUGINS = %w[discourse-local-dates]

  skip_before_action *%i[
                       check_xhr
                       preload_json
                       redirect_to_login_if_required
                       redirect_to_profile_if_required
                     ]
  layout false

  def theme
    raise Discourse::NotFound.new if !can_see_theme_qunit?

    @has_test_bundle = EmberCli.has_tests?

    param_key = nil
    @suggested_themes = nil
    if (id = get_param(:id)).present?
      theme = Theme.find_by(id: id.to_i)
      param_key = :id
    elsif (name = get_param(:name)).present?
      theme = Theme.find_by(name: name)
      param_key = :name
    elsif (url = get_param(:url)).present?
      theme = RemoteTheme.find_by(remote_url: url)&.theme
      param_key = :url
    end

    if param_key && theme.blank?
      return(
        render plain: "Can't find theme with #{param_key} #{get_param(param_key).inspect}",
               status: :not_found
      )
    end

    if !param_key
      @suggested_themes =
        Theme
          .where(
            id: ThemeField.where(target_id: Theme.targets[:tests_js]).distinct.pluck(:theme_id),
          )
          .order(updated_at: :desc)
          .pluck(:id, :name)
      return
    end

    about_json =
      JSON.parse(theme.theme_fields.find_by(target_id: Theme.targets[:about])&.value || "{}")
    @required_plugins =
      about_json
        .dig("tests", "requiredPlugins")
        &.map { |p| p.split("/").last.delete_suffix(".git") } || []

    request.env[:resolved_theme_id] = theme.id
    request.env[:skip_theme_ids_transformation] = true
  end

  protected

  def can_see_theme_qunit?
    return true if !Rails.env.production?
    current_user&.admin?
  end

  private

  def get_param(key)
    params[:"theme_#{key}"] || params[key]
  end
end

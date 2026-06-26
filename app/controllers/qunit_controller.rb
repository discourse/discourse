# frozen_string_literal: true

class QunitController < ApplicationController
  ALWAYS_LOADED_PLUGINS = %w[discourse-local-dates]

  skip_before_action *%i[
                       check_xhr
                       preload_json
                       redirect_to_login_if_required
                       redirect_to_profile_if_required
                     ]

  layout false
  around_action :ensure_locale_en

  def index
    raise Discourse::NotFound.new if !can_see_theme_qunit?
    @suggested_themes =
      Theme
        .where(id: ThemeField.where(target_id: Theme.targets[:tests_js]).distinct.pluck(:theme_id))
        .order(updated_at: :desc)
        .pluck(:id, :name)
  end

  def core
    @has_test_bundle = EmberAssets.has_tests?
    request.env[:resolved_theme_id] = nil

    target = params[:target] || "core"

    @required_plugins = []
    @testing_plugins = []

    if target == "plugins"
      @required_plugins.push(*Discourse.plugins.map(&:directory_name))
      @testing_plugins.push(*Discourse.plugins.map(&:directory_name))
    elsif target == "core"
      # no plugins
    elsif target_plugin = Discourse.plugins.find { |p| p.directory_name == target }
      @required_plugins << target_plugin.directory_name
      @testing_plugins << target_plugin.directory_name

      target_plugin.test_required_plugins&.map do |plugin_name|
        additional_plugin = Discourse.plugins.find { |p| p.directory_name == plugin_name }
        @required_plugins << additional_plugin.directory_name if additional_plugin
      end

      @required_plugins.push(*QunitController::ALWAYS_LOADED_PLUGINS)
    else
      return render plain: "Target '#{target}' not found", status: :not_found
    end

    render "qunit"
  end

  def theme
    raise Discourse::NotFound.new if !can_see_theme_qunit?

    @has_test_bundle = EmberAssets.has_tests?

    param_key = nil
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

    about_json =
      JSON.parse(theme.theme_fields.find_by(target_id: Theme.targets[:about])&.value || "{}")
    @required_plugins =
      about_json
        .dig("tests", "requiredPlugins")
        &.map { |p| p.split("/").last.delete_suffix(".git") } || []

    @required_plugins.push(*ALWAYS_LOADED_PLUGINS)

    request.env[:resolved_theme_id] = theme.id
    request.env[:skip_theme_ids_transformation] = true

    render "qunit"
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

  def ensure_locale_en
    I18n.with_locale(:en) { yield }
  end
end

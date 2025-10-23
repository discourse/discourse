# frozen_string_literal: true

class BootstrapController < ApplicationController
  skip_before_action :redirect_to_login_if_required, :check_xhr

  def core_css_for_tests
    targets = %w[color_definitions common desktop admin]
    render_css_for_tests(targets)
  end

  def plugin_test_info
    target = params[:target]

    required_plugins = []
    testing_plugins = []

    if target == "all" || target == "plugins"
      required_plugins.push(*Discourse.plugins.map(&:directory_name))
      testing_plugins.push(*Discourse.plugins.map(&:directory_name))
    elsif target == "core"
      # no plugins
    elsif target_plugin = Discourse.plugins.find { |p| p.directory_name == target }
      required_plugins << target_plugin.directory_name
      testing_plugins << target_plugin.directory_name

      target_plugin.test_required_plugins&.map do |plugin_name|
        additional_plugin = Discourse.plugins.find { |p| p.directory_name == plugin_name }
        required_plugins << additional_plugin.directory_name if additional_plugin
      end

      required_plugins.push(*QunitController::ALWAYS_LOADED_PLUGINS)
    else
      return render plain: "Target '#{target}' not found", status: :not_found
    end

    plugin_js_string =
      render_to_string partial: "layouts/plugin_js",
                       locals: {
                         opts: {
                           include_disabled: true,
                           include_admin_asset: true,
                           include_test_assets_for: testing_plugins,
                           only: required_plugins,
                         },
                       },
                       formats: [:html],
                       layout: false

    plugin_css_string =
      Discourse
        .find_plugin_css_assets(include_disabled: true, desktop_view: true, only: required_plugins)
        .map { |file| helpers.discourse_stylesheet_link_tag(file) }
        .join("\n")

    site_settings_json = SiteSetting.client_settings_json_uncached(return_defaults: true)

    render json: {
             all_plugins: Discourse.plugins.map(&:directory_name),
             site_settings_json:,
             html: "#{plugin_js_string}\n#{plugin_css_string}",
           }
  end

  private

  def render_css_for_tests(targets)
    urls =
      targets.map do |target|
        details = Stylesheet::Manager.new().stylesheet_details(target, "all")
        details[0][:new_href]
      end

    stylesheet = <<~CSS
      /* For use in tests only */
      #{urls.map { |url| "@import \"#{url}\";" }.join("\n")}
    CSS

    render plain: stylesheet, content_type: "text/css"
  end
end

# frozen_string_literal: true

class BootstrapController < ApplicationController
  skip_before_action :redirect_to_login_if_required, :check_xhr

  def plugin_css_for_tests
    targets = Discourse.find_plugin_css_assets(include_disabled: true, desktop_view: true)
    render_css_for_tests(targets)
  end

  def core_css_for_tests
    targets = %w[color_definitions common desktop admin]
    render_css_for_tests(targets)
  end

  def plugin_js_for_tests
    target = params[:target]
    target_plugin = Discourse.plugins.find { |p| p.directory_name == target }

    return render plain: "Target plugin not found", status: :not_found if target_plugin.nil?

    required_plugins = [target_plugin.directory_name]

    target_plugin.test_required_plugins&.map do |plugin_name|
      additional_plugin = Discourse.plugins.find { |p| p.directory_name == plugin_name }
      required_plugins << additional_plugin.directory_name if additional_plugin
    end

    required_plugins.push(*QunitController::ALWAYS_LOADED_PLUGINS)

    plugin_js_string =
      render_to_string partial: "layouts/plugin_js",
                       locals: {
                         opts: {
                           include_disabled: true,
                           include_admin_asset: true,
                           include_test_assets_for: [target_plugin.directory_name],
                           only: required_plugins,
                         },
                       },
                       formats: [:html],
                       layout: false

    render json: { all_plugins: Discourse.plugins.map(&:directory_name), html: plugin_js_string }
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

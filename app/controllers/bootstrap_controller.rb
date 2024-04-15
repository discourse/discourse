# frozen_string_literal: true

class BootstrapController < ApplicationController
  skip_before_action :redirect_to_login_if_required, :check_xhr

  def plugin_css_for_tests
    urls =
      Discourse
        .find_plugin_css_assets(include_disabled: true, desktop_view: true)
        .map do |target|
          details = Stylesheet::Manager.new().stylesheet_details(target, "all")
          details[0][:new_href]
        end

    stylesheet = <<~CSS
      /* For use in tests only - `@import`s all plugin stylesheets */
      #{urls.map { |url| "@import \"#{url}\";" }.join("\n")}
    CSS

    render plain: stylesheet, content_type: "text/css"
  end
end

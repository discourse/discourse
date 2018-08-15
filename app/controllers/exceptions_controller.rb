class ExceptionsController < ApplicationController
  skip_before_action :check_xhr, :preload_json
  before_action :hide_search

  def not_found
    # centralize all rendering of 404 into app controller
    raise Discourse::NotFound
  end

  # Give us an endpoint to use for 404 content in the ember app
  def not_found_body
    render html: build_not_found_page(200, false)
  end

  private

  def hide_search
    @hide_search = true if SiteSetting.login_required
  end

end

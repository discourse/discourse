class ExceptionsController < ApplicationController
  skip_before_filter :check_xhr, :preload_json

  def not_found
    @hide_google = true if SiteSetting.login_required

    # centralize all rendering of 404 into app controller
    raise Discourse::NotFound
  end

  # Give us an endpoint to use for 404 content in the ember app
  def not_found_body

    # Don't show google search if it's embedded in the Ember app
    @hide_google = true

    render text: build_not_found_page(200, false)
  end

end

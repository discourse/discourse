# frozen_string_literal: true

class ExceptionsController < ApplicationController
  skip_before_action :check_xhr

  def not_found
    # centralize all rendering of 404 into app controller
    raise Discourse::NotFound
  end

  # Give us an endpoint to use for 404 content in the ember app
  def not_found_body
    render html: build_not_found_page(status: 200)
  end
end

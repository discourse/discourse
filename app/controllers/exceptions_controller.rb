class ExceptionsController < ApplicationController
  skip_before_filter :check_xhr, :preload_json

  def not_found
    # centralize all rendering of 404 into app controller
    raise Discourse::NotFound
  end

end

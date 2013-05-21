class ExceptionsController < ApplicationController
  skip_before_filter :check_xhr

  def not_found
    # centralize all rendering of 404 into app controller
    raise Discourse::NotFound
  end

end

class AboutController < ApplicationController
  skip_before_filter :check_xhr, only: [:show]

  def index
    @about = About.new
    render_serialized(@about, AboutSerializer)
  end
end

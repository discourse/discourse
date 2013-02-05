class FaqController < ApplicationController

  skip_before_filter :check_xhr 

  def index
    render layout: false
  end

end
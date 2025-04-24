# frozen_string_literal: true

class ReviewController < ApplicationController
  skip_before_action :check_xhr

  def show
    render layout: "no_ember"
  end
end

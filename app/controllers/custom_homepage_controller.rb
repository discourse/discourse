# frozen_string_literal: true

class CustomHomepageController < ApplicationController
  def index
    render "default/custom"
  end
end

# frozen_string_literal: true

class CustomHomepageController < ApplicationController
  skip_before_action :check_xhr, only: [:index]

  def index
    respond_to { |format| format.html { render :index } }
  end
end

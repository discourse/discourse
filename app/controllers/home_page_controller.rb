# frozen_string_literal: true

class HomePageController < ApplicationController
  skip_before_action :check_xhr, only: %i[custom blank]

  def custom
    respond_to { |format| format.html { render :custom } }
  end

  def blank
    respond_to { |format| format.html { render "default/blank" } }
  end
end

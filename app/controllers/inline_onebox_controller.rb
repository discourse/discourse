require_dependency 'inline_oneboxer'

class InlineOneboxController < ApplicationController
  requires_login

  def show
    oneboxes = InlineOneboxer.new(params[:urls] || []).process
    render json: { "inline-oneboxes" => oneboxes }
  end
end

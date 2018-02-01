require_dependency 'inline_oneboxer'

class InlineOneboxController < ApplicationController
  prepend_before_action :check_xhr, :ensure_logged_in

  def show
    oneboxes = InlineOneboxer.new(params[:urls] || []).process
    render json: { "inline-oneboxes" => oneboxes }
  end
end

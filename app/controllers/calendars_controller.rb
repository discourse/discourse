# frozen_string_literal: true

class CalendarsController < ApplicationController
  skip_before_action :check_xhr, only: [ :index ], if: :ics_request?
  requires_login

  def download
    @post = Post.find(calendar_params[:post_id])
    @title = calendar_params[:title]
    @dates = calendar_params[:dates].values

    guardian.ensure_can_see!(@post)

    respond_to do |format|
      format.ics do
        filename = "events-#{@title.parameterize}"
        response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}.#{request.format.symbol}\""
      end
    end
  end

  private

  def ics_request?
    request.format.symbol == :ics
  end

  def calendar_params
    params.permit(:post_id, :title, dates: [:starts_at, :ends_at])
  end
end

class ClicksController < ApplicationController

  skip_before_filter :check_xhr

  def track
    params = track_params.merge(ip: request.remote_ip)

    if params[:topic_id].present? || params[:post_id].present?
      params.merge!({ user_id: current_user.id }) if current_user.present?
      @redirect_url = TopicLinkClick.create_from(params)
    end

    if @redirect_url.blank?
      # Couldn't find the URL in the post. give the user an escape hatch
      @given_url = params[:url]
      render template: 'clicks/failure', layout: false
    elsif params[:redirect] == 'false'
      # This is set by the JS when we're tracking an internal link
      render nothing: true, status: 204
    else
      redirect_to(@redirect_url)
    end
  end

  private

    def track_params
      params.require(:url)
      params.permit(:url, :post_id, :topic_id, :redirect)
    end

end

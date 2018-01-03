class ClicksController < ApplicationController

  skip_before_action :check_xhr, :preload_json

  def track
    raise Discourse::NotFound unless params[:url]

    params = track_params.merge(ip: request.remote_ip)

    if params[:topic_id].present? || params[:post_id].present?
      params.merge!(user_id: current_user.id) if current_user.present?
      @redirect_url = TopicLinkClick.create_from(params)
    end

    # links in whispers aren't extracted, just allow the redirection to staff
    if @redirect_url.blank? && current_user&.staff? && params[:post_id].present?
      @redirect_url = params[:url] if Post.exists?(id: params[:post_id], post_type: Post.types[:whisper])
    end

    # Sometimes we want to record a link without a 302.
    # Since XHR has to load the redirected URL we want it to not return a 302 in those cases.
    if params[:redirect] == "false" || @redirect_url.blank?
      render body: nil
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

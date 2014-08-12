class ClicksController < ApplicationController

  skip_before_filter :check_xhr

  def track
    # Sometimes we want to record a link without a 302. Since XHR has to load the redirected
    # URL we want it to not return a 302 in those cases.
    if params[:redirect] == 'false' || redirect_url.blank?
      render nothing: true
    else
      redirect_to(redirect_url)
    end
  end

  private

    def track_params
      params.require(:url)
      params.permit(:url, :post_id, :topic_id, :redirect)
    end
    
    def redirect_url
      @redirect_url ||= -> {
        return nil unless params[:topic_id].present? || params[:post_id].present?
        link = TopicLinkClick.create_from(user_params)
        (link.blank? && user_params[:url].index('?')) ? TopicLinkClick.create_from(strip_queries(user_params))
                                                     : link
      }.()
    end
    
    def strip_queries(params)
      params.dup.tap { |p| p[:url].sub!(/\?.*$/, '') }
    end
    
    def user_params
      @user_params ||= -> {
        _ = track_params.merge(ip: request.remote_ip)
        _.merge({ user_id: current_user.id }) if current_user.present?
        _
      }.()
    end
end

class ClicksController < ApplicationController

  skip_before_filter :check_xhr

  def track
    requires_parameter(:url)
    if params[:topic_id].present? || params[:post_id].present?
      args = {url: params[:url], ip: request.remote_ip}
      args[:user_id] = current_user.id if current_user.present?
      args[:post_id] = params[:post_id].to_i if params[:post_id].present?
      args[:topic_id] = params[:topic_id].to_i if params[:topic_id].present?

      TopicLinkClick.create_from(args)
    end

    # Sometimes we want to record a link without a 302. Since XHR has to load the redirected
    # URL we want it to not return a 302 in those cases.
    if params[:redirect] == 'false'
      render nothing: true
    else
      redirect_to(params[:url])
    end
  end

end

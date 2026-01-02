# frozen_string_literal: true

class LlmsTxtController < ApplicationController
  layout false
  skip_before_action :preload_json,
                     :check_xhr,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required

  def index
    content = SiteSetting.llms_txt_content
    return head(:not_found) if content.blank?

    render plain: content, content_type: "text/plain"
  end
end

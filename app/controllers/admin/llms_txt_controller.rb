# frozen_string_literal: true

class Admin::LlmsTxtController < Admin::AdminController
  def show
    render json: { llms_txt: SiteSetting.llms_txt_content }
  end

  def update
    params.require(:llms_txt)
    SiteSetting.llms_txt_content = params[:llms_txt]
    render json: { llms_txt: SiteSetting.llms_txt_content }
  end

  def reset
    SiteSetting.llms_txt_content = ""
    render json: { llms_txt: "" }
  end
end

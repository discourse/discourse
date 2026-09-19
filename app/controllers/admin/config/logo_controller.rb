# frozen_string_literal: true
class Admin::Config::LogoController < Admin::AdminController
  def index
  end

  def og_image_preview
    raise Discourse::InvalidParameters.new(:topic_id) if params[:topic_id].blank?

    topic = Topic.find_by(id: params[:topic_id])
    raise Discourse::NotFound if topic.nil?

    if !TopicOgImageGenerator.eligible?(topic)
      render json: {
               error: I18n.t("topic_og_image.preview_not_eligible"),
             },
             status: :unprocessable_entity
      return
    end

    png_bytes = TopicOgImageGenerator.new(topic).generate_bytes

    if png_bytes.blank?
      render json: {
               error: I18n.t("topic_og_image.preview_generation_failed"),
             },
             status: :unprocessable_entity
      return
    end

    data_uri = "data:image/png;base64,#{Base64.strict_encode64(png_bytes)}"
    render json: { url: data_uri, topic_id: topic.id, topic_title: topic.title }
  end

  def update
    settings =
      %i[
        logo
        logo_dark
        large_icon
        favicon
        logo_small
        logo_small_dark
        mobile_logo
        mobile_logo_dark
        manifest_icon
        manifest_screenshots
        apple_touch_icon
        digest_logo
        generate_topic_og_image
        opengraph_image
        x_summary_large_image
      ].filter_map do |setting|
        next if SiteSetting.hidden_settings.include?(setting)
        { setting_name: setting, value: params[setting] }
      end

    SiteSetting::Update.call(guardian:, params: { settings: }) do
      on_success { render json: success_json }
      on_failed_policy(:settings_are_visible) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:settings_are_unshadowed_globally) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:settings_are_configurable) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:values_are_valid) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
    end
  end
end

# frozen_string_literal: true
class Admin::Config::LogoController < Admin::AdminController
  def index
  end

  def og_image_preview
    if params[:topic_id].present?
      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound if topic.nil?
    else
      topic = Topic.visible.listable_topics.order("posts_count DESC").first
    end

    if topic.nil?
      topic =
        Topic.new(
          title: "Welcome to #{SiteSetting.title}",
          category: Category.first,
          like_count: 5,
          posts_count: 3,
        )
    end

    generator = TopicOgImageGenerator.new(topic)
    upload = generator.generate

    if upload&.errors&.empty?
      render json: { url: upload.url, topic_id: topic.id, topic_title: topic.title }
    else
      render json: { error: "Failed to generate preview image" }, status: :unprocessable_entity
    end
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

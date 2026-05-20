# frozen_string_literal: true

class DiscourseChatIntegration::ChatController < ApplicationController
  requires_plugin DiscourseChatIntegration::PLUGIN_NAME

  SETUP_PROVIDER_SITE_SETTING_KEYS = {
    "slack" => %i[chat_integration_slack_access_token chat_integration_slack_outbound_webhook_url],
    "telegram" => %i[chat_integration_telegram_access_token],
  }.freeze

  def respond
    render
  end

  def list_providers
    providers =
      DiscourseChatIntegration::Provider.enabled_providers.map do |provider_klass|
        {
          name: provider_klass::PROVIDER_NAME,
          id: provider_klass::PROVIDER_NAME,
          channel_parameters:
            (
              if (defined?(provider_klass::CHANNEL_PARAMETERS))
                provider_klass::CHANNEL_PARAMETERS
              else
                []
              end
            ),
        }
      end

    disabled_providers =
      DiscourseChatIntegration::Provider.disabled_providers.map do |provider_klass|
        {
          name: provider_klass::PROVIDER_NAME,
          id: provider_klass::PROVIDER_NAME,
          additional_site_settings_required:
            if defined?(provider_klass::ADDITIONAL_SITE_SETTINGS_REQUIRED)
              provider_klass::ADDITIONAL_SITE_SETTINGS_REQUIRED
            else
              false
            end,
        }
      end

    render json: { enabled_providers: providers, disabled_providers: }
  end

  def setup_provider
    hash = params.require(:provider).permit(:name)
    name = hash[:name].to_s.strip

    if name.blank?
      raise Discourse::InvalidParameters.new(
              I18n.t("chat_integration.errors.provider_not_found", name: "unknown"),
            )
    end

    provider_klass = DiscourseChatIntegration::Provider.get_by_name(name)
    if provider_klass.nil?
      raise Discourse::InvalidParameters.new(
              I18n.t("chat_integration.errors.provider_not_found", name: name),
            )
    end

    if DiscourseChatIntegration::Provider.is_enabled(provider_klass)
      raise Discourse::InvalidParameters.new(
              I18n.t("chat_integration.errors.provider_already_enabled", name: name),
            )
    end

    permitted_site_settings = permitted_provider_site_settings(name)

    DiscourseChatIntegration::Provider.setup(provider_klass, current_user, permitted_site_settings)
    render json: success_json
  rescue Discourse::InvalidParameters => err
    render json: { errors: [err.message] }, status: :unprocessable_entity
  rescue DiscourseChatIntegration::ProviderError => err
    if err.info[:error_key].present?
      render json: { error_key: err.info[:error_key] }, status: :unprocessable_entity
    else
      render json: { errors: [err.message.presence || "error"] }, status: :unprocessable_entity
    end
  end

  def test
    begin
      channel_id = params[:channel_id].to_i
      topic_id = params[:topic_id].to_i

      channel = DiscourseChatIntegration::Channel.find(channel_id)
      provider = DiscourseChatIntegration::Provider.get_by_name(channel.provider)

      raise Discourse::NotFound if !DiscourseChatIntegration::Provider.is_enabled(provider)

      post = Topic.find(topic_id.to_i).posts.first

      provider.trigger_notification(post, channel, nil)

      render json: success_json
    rescue Discourse::InvalidParameters, ActiveRecord::RecordNotFound => err
      render json: { errors: [err.message] }, status: :unprocessable_entity
    rescue DiscourseChatIntegration::ProviderError => err
      Rails.logger.error("Test provider failed #{err.info}")
      if err.info.key?(:error_key) && !err.info[:error_key].nil?
        render json: { error_key: err.info[:error_key] }, status: :unprocessable_entity
      else
        render json: { errors: [err.message] }, status: :unprocessable_entity
      end
    end
  end

  def list_channels
    providers = DiscourseChatIntegration::Provider.enabled_provider_names
    requested_provider = params[:provider]

    raise Discourse::InvalidParameters if !providers.include?(requested_provider)

    channels = DiscourseChatIntegration::Channel.with_provider(requested_provider)
    render_serialized channels, DiscourseChatIntegration::ChannelSerializer, root: "channels"
  end

  def create_channel
    begin
      providers = DiscourseChatIntegration::Provider.enabled_providers.map { |x| x::PROVIDER_NAME }

      if !defined?(params[:channel]) && defined?(params[:channel][:provider])
        raise Discourse::InvalidParameters, "Provider is not valid"
      end

      requested_provider = params[:channel][:provider]

      if !providers.include?(requested_provider)
        raise Discourse::InvalidParameters, "Provider is not valid"
      end

      allowed_keys =
        DiscourseChatIntegration::Provider.get_by_name(
          requested_provider,
        )::CHANNEL_PARAMETERS.map { |p| p[:key].to_sym }

      hash = params.require(:channel).permit(:provider, data: allowed_keys)

      channel = DiscourseChatIntegration::Channel.new(hash)

      raise Discourse::InvalidParameters, "Channel is not valid" if !channel.save

      render_serialized channel, DiscourseChatIntegration::ChannelSerializer, root: "channel"
    rescue Discourse::InvalidParameters => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  end

  def update_channel
    begin
      channel = DiscourseChatIntegration::Channel.find(params[:id].to_i)
      channel.error_key = nil # Reset any error on the rule

      allowed_keys =
        DiscourseChatIntegration::Provider.get_by_name(
          channel.provider,
        )::CHANNEL_PARAMETERS.map { |p| p[:key].to_sym }

      hash = params.require(:channel).permit(data: allowed_keys)

      raise Discourse::InvalidParameters, "Channel is not valid" if !channel.update(hash)

      render_serialized channel, DiscourseChatIntegration::ChannelSerializer, root: "channel"
    rescue Discourse::InvalidParameters => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  end

  def destroy_channel
    rule = DiscourseChatIntegration::Channel.find_by(id: params[:id])
    raise Discourse::InvalidParameters unless rule
    rule.destroy!

    render json: success_json
  end

  def create_rule
    begin
      hash =
        params.require(:rule).permit(:channel_id, :type, :filter, :group_id, :category_id, tags: [])
      rule = DiscourseChatIntegration::Rule.new(hash)

      raise Discourse::InvalidParameters, "Rule is not valid" if !rule.save

      render_serialized rule, DiscourseChatIntegration::RuleSerializer, root: "rule"
    rescue Discourse::InvalidParameters => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  end

  def update_rule
    begin
      rule = DiscourseChatIntegration::Rule.find(params[:id].to_i)
      hash = params.require(:rule).permit(:type, :filter, :group_id, :category_id, tags: [])

      raise Discourse::InvalidParameters, "Rule is not valid" if !rule.update(hash)

      render_serialized rule, DiscourseChatIntegration::RuleSerializer, root: "rule"
    rescue Discourse::InvalidParameters => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  end

  def destroy_rule
    rule = DiscourseChatIntegration::Rule.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new unless rule
    rule.destroy!

    render json: success_json
  end

  private

  def permitted_provider_site_settings(provider_name)
    keys = SETUP_PROVIDER_SITE_SETTING_KEYS[provider_name]
    return {} unless keys
    return {} if params[:provider_site_settings].blank?

    params[:provider_site_settings].permit(*keys).to_h.with_indifferent_access
  end
end

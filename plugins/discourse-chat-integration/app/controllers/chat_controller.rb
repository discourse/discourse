# frozen_string_literal: true

class DiscourseChatIntegration::ChatController < ApplicationController
  requires_plugin DiscourseChatIntegration::PLUGIN_NAME

  def respond
    render
  end

  def list_providers
    providers =
      ::DiscourseChatIntegration::Provider.enabled_providers.map do |x|
        {
          name: x::PROVIDER_NAME,
          id: x::PROVIDER_NAME,
          channel_parameters: (defined?(x::CHANNEL_PARAMETERS)) ? x::CHANNEL_PARAMETERS : [],
        }
      end

    render json: providers, root: "providers"
  end

  def test
    begin
      channel_id = params[:channel_id].to_i
      topic_id = params[:topic_id].to_i

      channel = DiscourseChatIntegration::Channel.find(channel_id)

      provider = ::DiscourseChatIntegration::Provider.get_by_name(channel.provider)

      raise Discourse::NotFound if !DiscourseChatIntegration::Provider.is_enabled(provider)

      post = Topic.find(topic_id.to_i).posts.first

      provider.trigger_notification(post, channel, nil)

      render json: success_json
    rescue Discourse::InvalidParameters, ActiveRecord::RecordNotFound => e
      render json: { errors: [e.message] }, status: 422
    rescue DiscourseChatIntegration::ProviderError => e
      Rails.logger.error("Test provider failed #{e.info}")
      if e.info.key?(:error_key) && !e.info[:error_key].nil?
        render json: { error_key: e.info[:error_key] }, status: 422
      else
        render json: { errors: [e.message] }, status: 422
      end
    end
  end

  def list_channels
    providers = ::DiscourseChatIntegration::Provider.enabled_provider_names
    requested_provider = params[:provider]

    raise Discourse::InvalidParameters if !providers.include?(requested_provider)

    channels = DiscourseChatIntegration::Channel.with_provider(requested_provider)
    render_serialized channels, DiscourseChatIntegration::ChannelSerializer, root: "channels"
  end

  def create_channel
    begin
      providers =
        ::DiscourseChatIntegration::Provider.enabled_providers.map { |x| x::PROVIDER_NAME }

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
      render json: { errors: [e.message] }, status: 422
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
      render json: { errors: [e.message] }, status: 422
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
      render json: { errors: [e.message] }, status: 422
    end
  end

  def update_rule
    begin
      rule = DiscourseChatIntegration::Rule.find(params[:id].to_i)
      hash = params.require(:rule).permit(:type, :filter, :group_id, :category_id, tags: [])

      raise Discourse::InvalidParameters, "Rule is not valid" if !rule.update(hash)

      render_serialized rule, DiscourseChatIntegration::RuleSerializer, root: "rule"
    rescue Discourse::InvalidParameters => e
      render json: { errors: [e.message] }, status: 422
    end
  end

  def destroy_rule
    rule = DiscourseChatIntegration::Rule.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new unless rule
    rule.destroy!

    render json: success_json
  end
end

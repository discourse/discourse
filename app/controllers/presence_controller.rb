# frozen_string_literal: true

class PresenceController < ApplicationController
  skip_before_action :check_xhr
  before_action :ensure_logged_in, only: [:update]

  def get
    name = params.require(:channel)

    begin
      channel = PresenceChannel.new(name)
    rescue PresenceChannel::NotFound
      raise Discourse::NotFound
    end

    if !channel.can_view?(user_id: current_user&.id)
      # Do not reveal existence of channel
      raise Discourse::NotFound
    end

    state = channel.state
    render json: state, serializer: PresenceChannelStateSerializer, root: nil
  end

  def update
    client_id = params[:client_id]
    raise Discourse::InvalidParameters.new(:client_id) if !client_id.is_a?(String) || client_id.blank?

    # JS client is designed to throttle to one request every 5 seconds
    RateLimiter.new(nil, "update-presence-#{current_user.id}-#{client_id}}", 3, 10.seconds).performed!

    present_channels = params[:present_channels]
    if present_channels && !(present_channels.is_a?(Array) && present_channels.all? { |c| c.is_a? String })
      raise Discourse::InvalidParameters.new(:present_channels)
    end

    leave_channels = params[:leave_channels]
    if leave_channels && !(leave_channels.is_a?(Array) && leave_channels.all? { |c| c.is_a? String })
      raise Discourse::InvalidParameters.new(:leave_channels)
    end

    if present_channels && present_channels.length > 50
      raise Discourse::InvalidParameters.new("Too many present_channels")
    end

    response = {}

    present_channels&.each do |name|
      PresenceChannel.new(name).present(user_id: current_user&.id, client_id: params[:client_id])
      response[name] = true
    rescue PresenceChannel::NotFound, PresenceChannel::InvalidAccess
      response[name] = false
    end

    leave_channels&.each do |name|
      PresenceChannel.new(name).leave(user_id: current_user&.id, client_id: params[:client_id])
    rescue PresenceChannel::NotFound
      # Do nothing. Don't reveal that this channel doesn't exist
    end

    render json: response
  end

end

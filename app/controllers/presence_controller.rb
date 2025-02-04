# frozen_string_literal: true

class PresenceController < ApplicationController
  skip_before_action :check_xhr, :redirect_to_profile_if_required
  before_action :ensure_logged_in, only: [:update]
  before_action :skip_persist_session

  MAX_CHANNELS_PER_REQUEST = 50

  def get
    names = params.require(:channels)
    if !(names.is_a?(Array) && names.all? { |n| n.is_a? String })
      raise Discourse::InvalidParameters.new(:channels)
    end

    names.uniq!

    if names.length > MAX_CHANNELS_PER_REQUEST
      raise Discourse::InvalidParameters.new("Too many channels")
    end

    user_group_ids =
      if current_user
        GroupUser.where(user_id: current_user.id).pluck("group_id")
      else
        []
      end

    result = {}
    names.each do |name|
      channel = PresenceChannel.new(name)
      if channel.can_view?(user_id: current_user&.id, group_ids: user_group_ids)
        result[name] = PresenceChannelStateSerializer.new(channel.state, root: nil)
      else
        result[name] = nil
      end
    rescue PresenceChannel::NotFound
      result[name] = nil
    end

    render json: result
  end

  def update
    raise Discourse::ReadOnly if @readonly_mode

    client_id = params[:client_id]
    if !client_id.is_a?(String) || client_id.blank?
      raise Discourse::InvalidParameters.new(:client_id)
    end

    # JS client is designed to throttle to one request per second
    # When no changes are being made, it makes one request every 30 seconds
    RateLimiter.new(nil, "update-presence-#{current_user.id}", 20, 10.seconds).performed!

    present_channels = params[:present_channels]
    if present_channels &&
         !(present_channels.is_a?(Array) && present_channels.all? { |c| c.is_a? String })
      raise Discourse::InvalidParameters.new(:present_channels)
    end

    leave_channels = params[:leave_channels]
    if leave_channels &&
         !(leave_channels.is_a?(Array) && leave_channels.all? { |c| c.is_a? String })
      raise Discourse::InvalidParameters.new(:leave_channels)
    end

    if present_channels && present_channels.length > MAX_CHANNELS_PER_REQUEST
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

  private

  def skip_persist_session
    # Presence endpoints are often called asynchronously at the same time as other request,
    # and never need to modify the session. Skipping ensures that an unneeded cookie rotation
    # doesn't race against another request and cause issues.
    session.options[:skip] = true
  end
end

# frozen_string_literal: true

class UserApiKey::DeviceAuth::Grant
  PENDING_STATUS = "pending"
  AUTHORIZED_STATUS = "authorized"
  DENIED_STATUS = "denied"
  STATUSES = [PENDING_STATUS, AUTHORIZED_STATUS, DENIED_STATUS].freeze

  def self.build(params, client, scopes, expires_in_seconds, device_code)
    created_at = Time.zone.now

    new(
      status: :pending,
      device_code: device_code,
      application_name:
        if client.present?
          client.application_name.presence || params[:application_name]
        else
          params[:application_name]
        end,
      client_id: params[:client_id],
      public_key: UserApiKey::DeviceAuth::RequestValidator.public_key_str(params, client),
      nonce: params[:nonce],
      scopes: scopes,
      push_url: params[:push_url].presence,
      padding: params[:padding].presence,
      expires_in_seconds: expires_in_seconds,
      expires_at:
        expires_in_seconds.present? ? (created_at + expires_in_seconds.seconds).iso8601(6) : nil,
      unregistered_client: client.blank? || client.public_key.blank?,
      created_at: created_at.iso8601(6),
    )
  end

  def self.from_json(json)
    data = JSON.parse(json)
    return if !data.is_a?(Hash)

    new(**data.symbolize_keys)
  rescue JSON::ParserError, ArgumentError, TypeError
    nil
  end

  attr_reader :status,
              :device_code,
              :user_code,
              :request_token,
              :application_name,
              :client_id,
              :public_key,
              :nonce,
              :push_url,
              :padding,
              :expires_in_seconds,
              :payload,
              :authorizing_user_id

  attr_writer :scopes

  def initialize(
    status:,
    device_code:,
    user_code: nil,
    request_token: nil,
    application_name: nil,
    client_id: nil,
    public_key: nil,
    nonce: nil,
    scopes: nil,
    push_url: nil,
    padding: nil,
    expires_in_seconds: nil,
    expires_at: nil,
    unregistered_client: false,
    created_at: nil,
    payload: nil,
    authorized_at: nil,
    denied_at: nil,
    authorizing_user_id: nil,
    authorizing_username: nil,
    authorizing_at: nil
  )
    @status = normalize_status(status)
    validate_status!
    @device_code = device_code
    @user_code = user_code
    @request_token = request_token
    @application_name = application_name
    @client_id = client_id
    @public_key = public_key
    @nonce = nonce
    @scopes = scopes
    @push_url = push_url
    @padding = padding
    @expires_in_seconds = expires_in_seconds
    @created_at = created_at
    @expires_at = expires_at || default_expires_at&.iso8601(6)
    @unregistered_client = unregistered_client
    @payload = payload
    @authorized_at = authorized_at
    @denied_at = denied_at
    @authorizing_user_id = authorizing_user_id
    @authorizing_username = authorizing_username
    @authorizing_at = authorizing_at
  end

  def ==(other)
    other.is_a?(self.class) && to_h == other.to_h
  end

  def pending?
    status == PENDING_STATUS
  end

  def authorized?
    status == AUTHORIZED_STATUS
  end

  def denied?
    status == DENIED_STATUS
  end

  def scopes
    Array(@scopes)
  end

  def localized_scopes
    scopes.map { |scope| I18n.t("user_api_key.scopes.#{scope}") }
  end

  def write_scope?
    scopes.include?("write")
  end

  def expires_at
    return if @expires_at.blank?

    Time.zone.parse(@expires_at.to_s)
  end

  def unregistered_client?
    !!@unregistered_client
  end

  def assign_codes!(user_code:, request_token:)
    @user_code = user_code
    @request_token = request_token
  end

  def authorize!(payload:)
    @status = AUTHORIZED_STATUS
    @payload = payload
    @authorized_at = Time.zone.now.iso8601
  end

  def deny!
    @status = DENIED_STATUS
    @denied_at = Time.zone.now.iso8601
  end

  def bound_to_another_user?(user)
    authorizing_user_id.present? && authorizing_user_id != user.id
  end

  def authorized_for_user?(user)
    authorizing_user_id == user.id
  end

  def bind_to_user!(user)
    return false if bound_to_another_user?(user)
    return true if authorized_for_user?(user)

    @authorizing_user_id = user.id
    @authorizing_username = user.username
    @authorizing_at = Time.zone.now.iso8601
    true
  end

  def to_h
    {
      "status" => status,
      "device_code" => device_code,
      "user_code" => user_code,
      "request_token" => request_token,
      "application_name" => application_name,
      "client_id" => client_id,
      "public_key" => public_key,
      "nonce" => nonce,
      "scopes" => scopes,
      "push_url" => push_url,
      "padding" => padding,
      "expires_in_seconds" => expires_in_seconds,
      "expires_at" => @expires_at,
      "unregistered_client" => unregistered_client?,
      "created_at" => @created_at,
      "payload" => payload,
      "authorized_at" => @authorized_at,
      "denied_at" => @denied_at,
      "authorizing_user_id" => authorizing_user_id,
      "authorizing_username" => @authorizing_username,
      "authorizing_at" => @authorizing_at,
    }.compact
  end

  def as_json(*)
    to_h
  end

  def to_json(*args)
    to_h.to_json(*args)
  end

  private

  def normalize_status(status)
    status.to_s
  end

  def default_expires_at
    return if expires_in_seconds.blank?

    if @created_at.present?
      Time.zone.parse(@created_at.to_s) + expires_in_seconds.to_i.seconds
    else
      UserApiKey::Expiry.requested_expires_at(expires_in_seconds)
    end
  end

  def validate_status!
    return if STATUSES.include?(status)

    raise ArgumentError, "invalid device auth grant status: #{status}"
  end
end

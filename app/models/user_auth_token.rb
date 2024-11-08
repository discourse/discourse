# frozen_string_literal: true
require "digest/sha1"

class UserAuthToken < ActiveRecord::Base
  belongs_to :user

  ROTATE_TIME_MINS = 10
  ROTATE_TIME = ROTATE_TIME_MINS.minutes
  # used when token did not arrive at client
  URGENT_ROTATE_TIME = 1.minute

  MAX_SESSION_COUNT = 60

  USER_ACTIONS = ["generate"].freeze

  attr_accessor :unhashed_auth_token

  before_destroy do
    UserAuthToken.log_verbose(
      action: "destroy",
      user_auth_token_id: self.id,
      user_id: self.user_id,
      user_agent: self.user_agent,
      client_ip: self.client_ip,
      auth_token: self.auth_token,
    )
  end

  def self.log(info)
    UserAuthTokenLog.create!(info)
  end

  def self.log_verbose(info)
    log(info) if SiteSetting.verbose_auth_token_logging
  end

  RAD_PER_DEG = Math::PI / 180
  EARTH_RADIUS_KM = 6371 # kilometers

  def self.login_location(ip)
    ipinfo = DiscourseIpInfo.get(ip)

    ipinfo[:latitude] && ipinfo[:longitude] ? [ipinfo[:latitude], ipinfo[:longitude]] : nil
  end

  def self.distance(loc1, loc2)
    lat1_rad, lon1_rad = loc1[0] * RAD_PER_DEG, loc1[1] * RAD_PER_DEG
    lat2_rad, lon2_rad = loc2[0] * RAD_PER_DEG, loc2[1] * RAD_PER_DEG

    a =
      Math.sin((lat2_rad - lat1_rad) / 2)**2 +
        Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin((lon2_rad - lon1_rad) / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    c * EARTH_RADIUS_KM
  end

  def self.is_suspicious(user_id, user_ip)
    return false unless User.find_by(id: user_id)&.staff?

    ips = UserAuthTokenLog.where(user_id: user_id).pluck(:client_ip)
    ips.delete_at(ips.index(user_ip) || ips.length) # delete one occurrence (current)
    ips.uniq!
    return false if ips.empty? # first login is never suspicious

    if user_location = login_location(user_ip)
      ips.none? do |ip|
        if location = login_location(ip)
          distance(user_location, location) < SiteSetting.max_suspicious_distance_km
        end
      end
    end
  end

  def self.generate!(
    user_id:,
    user_agent: nil,
    client_ip: nil,
    path: nil,
    staff: nil,
    impersonate: false,
    authenticated_with_oauth: false
  )
    token = SecureRandom.hex(16)
    hashed_token = hash_token(token)
    user_auth_token =
      UserAuthToken.create!(
        user_id: user_id,
        user_agent: user_agent,
        client_ip: client_ip,
        auth_token: hashed_token,
        prev_auth_token: hashed_token,
        rotated_at: Time.zone.now,
        authenticated_with_oauth: !!authenticated_with_oauth,
      )
    user_auth_token.unhashed_auth_token = token

    log(
      action: "generate",
      user_auth_token_id: user_auth_token.id,
      user_id: user_id,
      user_agent: user_agent,
      client_ip: client_ip,
      path: path,
      auth_token: hashed_token,
    )

    if staff && !impersonate
      Jobs.enqueue(
        :suspicious_login,
        user_id: user_id,
        client_ip: client_ip,
        user_agent: user_agent,
      )
    end

    user_auth_token
  end

  def self.lookup(unhashed_token, opts = nil)
    mark_seen = opts && opts[:seen]

    token = hash_token(unhashed_token)
    expire_before = SiteSetting.maximum_session_age.hours.ago

    user_token =
      where(
        "(auth_token = :token OR
                          prev_auth_token = :token) AND rotated_at > :expire_before",
        token: token,
        expire_before: expire_before,
      )

    if SiteSetting.verbose_auth_token_logging && path = opts.dig(:path)
      user_token = user_token.annotate("path:#{path}")
    end

    user_token = user_token.first

    if !user_token
      log_verbose(
        action: "miss token",
        user_id: nil,
        auth_token: token,
        user_agent: opts && opts[:user_agent],
        path: opts && opts[:path],
        client_ip: opts && opts[:client_ip],
      )

      return nil
    end

    if user_token.auth_token != token && user_token.prev_auth_token == token &&
         user_token.auth_token_seen
      changed_rows =
        UserAuthToken
          .where("rotated_at < ?", 1.minute.ago)
          .where(id: user_token.id, prev_auth_token: token)
          .update_all(auth_token_seen: false)

      # not updating AR model cause we want to give it one more req
      # with wrong cookie
      UserAuthToken.log_verbose(
        action: changed_rows == 0 ? "prev seen token unchanged" : "prev seen token",
        user_auth_token_id: user_token.id,
        user_id: user_token.user_id,
        auth_token: user_token.auth_token,
        user_agent: opts && opts[:user_agent],
        path: opts && opts[:path],
        client_ip: opts && opts[:client_ip],
      )
    end

    if mark_seen && user_token && !user_token.auth_token_seen && user_token.auth_token == token
      # we must protect against concurrency issues here
      changed_rows =
        UserAuthToken.where(id: user_token.id, auth_token: token).update_all(
          auth_token_seen: true,
          seen_at: Time.zone.now,
        )

      if changed_rows == 1
        # not doing a reload so we don't risk loading a rotated token
        user_token.auth_token_seen = true
        user_token.seen_at = Time.zone.now
      end

      log_verbose(
        action: changed_rows == 0 ? "seen wrong token" : "seen token",
        user_auth_token_id: user_token.id,
        user_id: user_token.user_id,
        auth_token: user_token.auth_token,
        user_agent: opts && opts[:user_agent],
        path: opts && opts[:path],
        client_ip: opts && opts[:client_ip],
      )
    end

    user_token
  end

  def self.hash_token(token)
    Digest::SHA1.base64digest("#{token}#{GlobalSetting.safe_secret_key_base}")
  end

  def self.cleanup!
    if SiteSetting.verbose_auth_token_logging
      UserAuthTokenLog.where(
        "created_at < :time",
        time: SiteSetting.maximum_session_age.hours.ago - ROTATE_TIME,
      ).delete_all
    end

    where(
      "rotated_at < :time",
      time: SiteSetting.maximum_session_age.hours.ago - ROTATE_TIME,
    ).delete_all
  end

  def rotate!(info = nil)
    user_agent = (info && info[:user_agent] || self.user_agent)
    client_ip = (info && info[:client_ip] || self.client_ip)

    token = SecureRandom.hex(16)

    result =
      DB.exec(
        "
  UPDATE user_auth_tokens
  SET
    auth_token_seen = false,
    seen_at = null,
    user_agent = :user_agent,
    client_ip = :client_ip,
    prev_auth_token = case when auth_token_seen then auth_token else prev_auth_token end,
    auth_token = :new_token,
    rotated_at = :now
  WHERE id = :id AND (auth_token_seen or rotated_at < :safeguard_time)
",
        id: self.id,
        user_agent: user_agent,
        client_ip: client_ip&.to_s,
        now: Time.zone.now,
        new_token: UserAuthToken.hash_token(token),
        safeguard_time: 30.seconds.ago,
      )

    if result > 0
      reload
      self.unhashed_auth_token = token

      UserAuthToken.log(
        action: "rotate",
        user_auth_token_id: id,
        user_id: user_id,
        auth_token: auth_token,
        user_agent: user_agent,
        client_ip: client_ip,
        path: info && info[:path],
      )

      true
    else
      false
    end
  end

  def self.enforce_session_count_limit!(user_id)
    tokens_to_destroy =
      where(user_id: user_id)
        .where("rotated_at > ?", SiteSetting.maximum_session_age.hours.ago)
        .order("rotated_at DESC")
        .offset(MAX_SESSION_COUNT)

    tokens_to_destroy.delete_all # Returns the number of deleted rows
  end
end

# == Schema Information
#
# Table name: user_auth_tokens
#
#  id                       :integer          not null, primary key
#  user_id                  :integer          not null
#  auth_token               :string           not null
#  prev_auth_token          :string           not null
#  user_agent               :string
#  auth_token_seen          :boolean          default(FALSE), not null
#  client_ip                :inet
#  rotated_at               :datetime         not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  seen_at                  :datetime
#  authenticated_with_oauth :boolean          default(FALSE)
#
# Indexes
#
#  index_user_auth_tokens_on_auth_token       (auth_token) UNIQUE
#  index_user_auth_tokens_on_prev_auth_token  (prev_auth_token) UNIQUE
#  index_user_auth_tokens_on_user_id          (user_id)
#

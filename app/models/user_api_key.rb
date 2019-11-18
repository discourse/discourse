# frozen_string_literal: true

class UserApiKey < ActiveRecord::Base

  SCOPES = {
    read: [:get],
    write: [:get, :post, :patch, :put, :delete],
    message_bus: [[:post, 'message_bus']],
    push: nil,
    one_time_password: nil,
    notifications: [[:post, 'message_bus'], [:get, 'notifications#index'], [:put, 'notifications#mark_read']],
    session_info: [
      [:get, 'session#current'],
      [:get, 'users#topic_tracking_state'],
      [:get, 'list#unread'],
      [:get, 'list#new'],
      [:get, 'list#latest']
    ]
  }

  belongs_to :user

  def self.allowed_scopes
    Set.new(SiteSetting.allow_user_api_key_scopes.split("|"))
  end

  def self.available_scopes
    @available_scopes ||= Set.new(SCOPES.keys.map(&:to_s))
  end

  def self.allow_permission?(permission, env)
    verb, action = permission
    actual_verb = env["REQUEST_METHOD"] || ""

    return false unless actual_verb.downcase == verb.to_s
    return true unless action

    # not a rails route, special handling
    return true if action == "message_bus" && env["PATH_INFO"] =~ /^\/message-bus\/.*\/poll/

    params = env['action_dispatch.request.path_parameters']

    return false unless params

    actual_action = "#{params[:controller]}##{params[:action]}"
    actual_action == action
  end

  def self.allow_scope?(name, env)
    if allowed = SCOPES[name.to_sym]
      good = allowed.any? do |permission|
        allow_permission?(permission, env)
      end

      good || allow_permission?([:post, 'user_api_keys#revoke'], env)
    end
  end

  def has_push?
    (scopes.include?("push") || scopes.include?("notifications")) && push_url.present? && SiteSetting.allowed_user_api_push_urls.include?(push_url)
  end

  def allow?(env)
    scopes.any? do |name|
      UserApiKey.allow_scope?(name, env)
    end
  end

  def self.invalid_auth_redirect?(auth_redirect)
    SiteSetting.allowed_user_api_auth_redirects
      .split('|')
      .none? { |u| WildcardUrlChecker.check_url(u, auth_redirect) }
  end
end

# == Schema Information
#
# Table name: user_api_keys
#
#  id               :integer          not null, primary key
#  user_id          :integer          not null
#  client_id        :string           not null
#  key              :string           not null
#  application_name :string           not null
#  push_url         :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  revoked_at       :datetime
#  scopes           :text             default([]), not null, is an Array
#  last_used_at     :datetime         not null
#
# Indexes
#
#  index_user_api_keys_on_client_id  (client_id) UNIQUE
#  index_user_api_keys_on_key        (key) UNIQUE
#  index_user_api_keys_on_user_id    (user_id)
#

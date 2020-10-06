# frozen_string_literal: true

class UserApiKeyScope < ActiveRecord::Base
  SCOPES = {
    read: [ RouteMatcher.new(methods: :get) ],
    write: [ RouteMatcher.new(methods: [:get, :post, :patch, :put, :delete]) ],
    message_bus: [ RouteMatcher.new(methods: :post, actions: 'message_bus') ],
    push: [],
    one_time_password: [],
    notifications: [
      RouteMatcher.new(methods: :post, actions: 'message_bus'),
      RouteMatcher.new(methods: :get, actions: 'notifications#index'),
      RouteMatcher.new(methods: :put, actions: 'notifications#mark_read')
    ],
    session_info: [ RouteMatcher.new(methods: :get, actions: 'session#current') ]
  }

  def self.all_scopes
    SCOPES
  end

  def permits?(env)
    matchers.any? { |m| m.match?(env: env) }
  end

  private

  def matchers
    @matchers ||= Array(self.class.all_scopes[name.to_sym])
  end

end

# == Schema Information
#
# Table name: user_api_key_scopes
#
#  id              :bigint           not null, primary key
#  user_api_key_id :integer          not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_user_api_key_scopes_on_user_api_key_id  (user_api_key_id)
#

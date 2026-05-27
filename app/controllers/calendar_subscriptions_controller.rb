# frozen_string_literal: true

class CalendarSubscriptionsController < ApplicationController
  requires_login

  CLIENT_ID = "calendar-subscriptions"

  before_action :rate_limit_create, only: :create

  def show
    render json: { has_subscription: find_calendar_api_key.present?, feeds: feed_names }
  end

  def create
    revoke_existing_key!

    client =
      UserApiKeyClient.find_or_create_by!(client_id: CLIENT_ID) do |c|
        c.application_name = I18n.t("calendar_subscriptions.application_name")
      end

    scopes = build_scopes
    api_key = client.keys.create!(user_id: current_user.id, scopes: scopes)
    raw_key = api_key.key

    render json: { key: raw_key, urls: build_urls(raw_key) }
  end

  def destroy
    revoke_existing_key!
    head :no_content
  end

  private

  def find_calendar_api_key
    UserApiKey
      .active
      .joins(:client)
      .where(user_id: current_user.id, user_api_key_clients: { client_id: CLIENT_ID })
      .first
  end

  def revoke_existing_key!
    find_calendar_api_key&.update!(revoked_at: Time.zone.now)
  end

  def build_scopes
    scope_names = ["bookmarks_calendar"] + plugin_feeds.map { |f| f[:scope] }
    all_scopes = UserApiKeyScope.all_scopes
    scope_names.uniq.filter_map do |name|
      if all_scopes.key?(name.to_sym)
        UserApiKeyScope.new(name: name)
      else
        Rails.logger.warn("Calendar subscription feed references unknown scope: #{name}. Skipping.")
        nil
      end
    end
  end

  def build_urls(raw_key)
    base = Discourse.base_url
    username = current_user.username_lower

    urls = { bookmarks: "#{base}/u/#{username}/bookmarks.ics?user_api_key=#{raw_key}" }

    plugin_feeds.each do |feed|
      urls[feed[:name].to_sym] = feed[:url].call(base, current_user, raw_key)
    end

    urls
  end

  def feed_names
    names = ["bookmarks"]
    names += plugin_feeds.map { |f| f[:name] }
    names
  end

  def plugin_feeds
    @plugin_feeds ||= DiscoursePluginRegistry.calendar_subscription_feeds
  end

  def rate_limit_create
    RateLimiter.new(current_user, "calendar-subscriptions-create", 5, 1.minute).performed!
  end
end

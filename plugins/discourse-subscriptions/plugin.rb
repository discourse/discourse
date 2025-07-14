# frozen_string_literal: true

# name: discourse-subscriptions
# about: Allows admins to sell subscriptions to site content.
# meta_topic_id: 140818
# version: 2.8.1
# authors: Rimian Perkins, Justin DiRose
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-subscriptions

enabled_site_setting :discourse_subscriptions_enabled

require "stripe"

register_asset "stylesheets/common/main.scss"
register_asset "stylesheets/common/layout.scss"
register_asset "stylesheets/common/subscribe.scss"
register_asset "stylesheets/common/campaign.scss"
register_asset "stylesheets/mobile/main.scss"
register_svg_icon "far-credit-card" if respond_to?(:register_svg_icon)

register_html_builder("server:before-head-close") do |controller|
  "<script src='https://js.stripe.com/v3/' nonce='#{controller.helpers.csp_nonce_placeholder}'></script>"
end

register_html_builder("server:before-head-close") do |controller|
  "<script async src='https://js.stripe.com/v3/pricing-table.js' nonce='#{controller.helpers.csp_nonce_placeholder}'></script>"
end

extend_content_security_policy(script_src: %w[https://js.stripe.com/v3/ https://hooks.stripe.com])

add_admin_route "discourse_subscriptions.admin_navigation", "discourse-subscriptions.products"

Discourse::Application.routes.append do
  get "/admin/plugins/discourse-subscriptions" => "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/discourse-subscriptions/products" => "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/discourse-subscriptions/products/:product_id" => "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/discourse-subscriptions/products/:product_id/plans" => "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/discourse-subscriptions/products/:product_id/plans/:plan_id" =>
        "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/discourse-subscriptions/subscriptions" => "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/discourse-subscriptions/plans" => "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/discourse-subscriptions/plans/:plan_id" => "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/discourse-subscriptions/coupons" => "admin/plugins#index",
      :constraints => AdminConstraint.new
  get "u/:username/billing" => "users#show", :constraints => { username: USERNAME_ROUTE_FORMAT }
  get "u/:username/billing/:id" => "users#show", :constraints => { username: USERNAME_ROUTE_FORMAT }
  get "u/:username/billing/subscriptions/card/:subscription_id" => "users#show",
      :constraints => {
        username: USERNAME_ROUTE_FORMAT,
      }
end

module ::DiscourseSubscriptions
  PLUGIN_NAME = "discourse-subscriptions"
end

require_relative "lib/discourse_subscriptions/engine"
require_relative "app/controllers/concerns/stripe"
require_relative "app/controllers/concerns/group"

after_initialize do
  ::Stripe.api_version = "2024-04-10"

  ::Stripe.set_app_info(
    "Discourse Subscriptions",
    version: "2.8.2",
    url: "https://github.com/discourse/discourse-subscriptions",
  )

  Discourse::Application.routes.append { mount ::DiscourseSubscriptions::Engine, at: "s" }

  add_to_serializer(:site, :show_campaign_banner) do
    begin
      enabled = SiteSetting.discourse_subscriptions_enabled
      campaign_enabled = SiteSetting.discourse_subscriptions_campaign_enabled
      goal_met = Discourse.redis.get("subscriptions_goal_met_date")

      enabled && campaign_enabled && (!goal_met || 7.days.ago <= Date.parse(goal_met))
    rescue StandardError
      false
    end
  end
end

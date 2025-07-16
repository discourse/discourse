# frozen_string_literal: true

# name: discourse-patreon
# about: Enables Patreon Social Login, and synchronization between Discourse Groups and Patreon rewards.
# meta_topic_id: 44366
# version: 2.0
# author: Rafael dos Santos Silva <xfalcox@gmail.com>
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-patreon

require "omniauth-oauth2"

enabled_site_setting :patreon_enabled

register_asset "stylesheets/patreon.scss"

register_svg_icon "patreon-new"

# Site setting validators must be loaded before initialize
require_relative "lib/validators/patreon_login_enabled_validator"

after_initialize do
  require_dependency "admin_constraint"

  module ::Patreon
    PLUGIN_NAME = "discourse-patreon".freeze
    USER_DETAIL_FIELDS = %w[id amount_cents rewards declined_since].freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Patreon
    end

    def self.store
      @store ||= PluginStore.new(PLUGIN_NAME)
    end

    def self.get(key)
      store.get(key)
    end

    def self.set(key, value)
      store.set(key, value)
    end

    def self.show_donation_prompt_to_user?(user)
      return false unless SiteSetting.patreon_donation_prompt_enabled?

      filters = get("filters") || {}
      filters = filters.keys.map(&:to_i)

      (user.visible_groups.pluck(:id) & filters).size <= 0
    end

    class Reward
      def self.all
        Patreon.get("rewards") || {}
      end
    end

    class RewardUser
      def self.all
        Patreon.get("reward-users") || {}
      end
    end
  end

  require_relative "app/controllers/patreon_admin_controller"
  require_relative "app/controllers/patreon_webhook_controller"
  require_relative "app/jobs/regular/sync_patron_groups"
  require_relative "app/jobs/scheduled/patreon_sync_patrons_to_groups"
  require_relative "app/jobs/scheduled/patreon_update_tokens"
  require_relative "app/services/problem_check/access_token_invalid"
  require_relative "lib/api"
  require_relative "lib/seed"
  require_relative "lib/campaign"
  require_relative "lib/pledge"
  require_relative "lib/patron"
  require_relative "lib/tokens"

  Patreon::Engine.routes.draw do
    get "/rewards" => "patreon_admin#rewards", :constraints => AdminConstraint.new
    get "/list" => "patreon_admin#list", :constraints => AdminConstraint.new
    post "/list" => "patreon_admin#edit", :constraints => AdminConstraint.new
    delete "/list" => "patreon_admin#delete", :constraints => AdminConstraint.new
    post "/sync_groups" => "patreon_admin#sync_groups", :constraints => AdminConstraint.new
    post "/update_data" => "patreon_admin#update_data", :constraints => AdminConstraint.new
    post "/webhook" => "patreon_webhook#index"
  end

  Discourse::Application.routes.prepend { mount ::Patreon::Engine, at: "/patreon" }

  add_admin_route "patreon.title", "patreon"

  Discourse::Application.routes.append do
    get "/admin/plugins/patreon" => "admin/plugins#index", :constraints => AdminConstraint.new
    get "/admin/plugins/patreon/list" => "patreon/patreon_admin#list",
        :constraints => AdminConstraint.new
    get "/u/:username/patreon_email" => "patreon/patreon_admin#email",
        :constraints => {
          username: RouteFormat.username,
        }
  end

  on(:user_created) do |user|
    filters = PluginStore.get(::Patreon::PLUGIN_NAME, "filters")
    patreon_id = Patreon::Patron.all.key(user.email)

    if filters.present? && patreon_id.present?
      begin
        reward_id =
          Patreon::RewardUser.all.except("0").detect { |_k, v| v.include? patreon_id }&.first

        group_ids = filters.select { |_k, v| v.include?(reward_id) || v.include?("0") }.keys

        Group.where(id: group_ids).each { |group| group.add user }

        Patreon::Patron.update_local_user(user, patreon_id, true)
      rescue => e
        Rails.logger.warn(
          "Patreon group membership callback failed for new user #{self.id} with error: #{e}.\n\n #{e.backtrace.join("\n")}",
        )
      end
    end
  end

  ::Patreon::USER_DETAIL_FIELDS.each do |attribute|
    add_to_serializer(
      :admin_detailed_user,
      "patreon_#{attribute}".to_sym,
      include_condition: -> do
        ::Patreon::Patron.attr(attribute, object).present? &&
          (attribute != "amount_cents" || scope.is_admin?)
      end,
    ) { ::Patreon::Patron.attr(attribute, object) }
  end

  add_to_serializer(
    :admin_detailed_user,
    :patreon_email_exists,
    include_condition: -> { ::Patreon::Patron.attr("email", object).present? },
  ) { true }

  add_to_serializer(:current_user, :show_donation_prompt?) do
    Patreon.show_donation_prompt_to_user?(object)
  end

  register_problem_check ProblemCheck::AccessTokenInvalid
end

# Authentication with Patreon
class ::OmniAuth::Strategies::Patreon < ::OmniAuth::Strategies::OAuth2
  option :name, "patreon"

  option :client_options,
         site: "https://www.patreon.com",
         authorize_url: "https://www.patreon.com/oauth2/authorize",
         token_url: "https://api.patreon.com/oauth2/token"

  option :authorize_params, response_type: "code"

  def custom_build_access_token
    verifier = request.params["code"]
    client.auth_code.get_token(verifier, redirect_uri: options.redirect_uri)
  end

  alias_method :build_access_token, :custom_build_access_token

  uid { raw_info["data"]["id"].to_s }

  info do
    {
      email: raw_info["data"]["attributes"]["email"],
      email_verified: raw_info["data"]["attributes"]["is_email_verified"],
      name: raw_info["data"]["attributes"]["full_name"],
    }
  end

  extra { { raw_info: raw_info } }

  def raw_info
    @raw_info ||=
      begin
        response =
          client.request(
            :get,
            "https://api.patreon.com/oauth2/api/current_user",
            headers: {
              "Authorization" => "Bearer #{access_token.token}",
            },
            parse: :json,
          )
        response.parsed
      end
  end

  def callback_url
    full_host + script_name + callback_path
  end
end

class Auth::PatreonAuthenticator < Auth::ManagedAuthenticator
  def name
    "patreon"
  end

  def register_middleware(omniauth)
    omniauth.provider :patreon,
                      setup:
                        lambda { |env|
                          strategy = env["omniauth.strategy"]
                          strategy.options[:client_id] = SiteSetting.patreon_client_id
                          strategy.options[:client_secret] = SiteSetting.patreon_client_secret
                          strategy.options[
                            :redirect_uri
                          ] = "#{Discourse.base_url}/auth/patreon/callback"
                          strategy.options[
                            :provider_ignores_state
                          ] = SiteSetting.patreon_login_ignore_state
                        }
  end

  def after_authenticate(auth_token, existing_account: nil)
    result = super

    user = result.user
    discourse_username = SiteSetting.patreon_creator_discourse_username
    if discourse_username.present? && user && user.username == discourse_username
      SiteSetting.patreon_creator_access_token = auth_token.credentials["token"]
      SiteSetting.patreon_creator_refresh_token = auth_token.credentials["refresh_token"]
    end

    result
  end

  def enabled?
    SiteSetting.patreon_login_enabled
  end

  def primary_email_verified?(auth_token)
    auth_token[:info][:email_verified]
  end
end

auth_provider authenticator: Auth::PatreonAuthenticator.new, icon: "patreon-new"

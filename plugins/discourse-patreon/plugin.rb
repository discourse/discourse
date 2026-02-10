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

register_svg_icon "fab-patreon"
register_svg_icon "patreon-new"

# Site setting validators must be loaded before initialize
require_relative "lib/validators/patreon_login_enabled_validator"

module ::Patreon
  PLUGIN_NAME = "discourse-patreon"
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: Patreon)
Rails.autoloaders.main.ignore(File.join(__dir__, "lib/validators"))

require_relative "lib/engine"

after_initialize do
  Discourse::Application.routes.prepend { mount Patreon::Engine, at: "/patreon" }

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
    next unless SiteSetting.patreon_enabled

    patron = PatreonPatron.where("LOWER(email) = ?", user.email.downcase).first

    if patron.present? && PatreonGroupRewardFilter.exists?
      begin
        patron_reward_ids = patron.patreon_rewards.pluck(:id)

        group_ids =
          PatreonGroupRewardFilter
            .where(patreon_reward_id: patron_reward_ids)
            .or(
              PatreonGroupRewardFilter.where(patreon_reward: PatreonReward.where(patreon_id: "0")),
            )
            .pluck(:group_id)
            .uniq

        Group.where(id: group_ids).each { |group| group.add user }

        Patreon::Patron.update_local_user(user, patron.patreon_id, true)
      rescue => e
        Rails.logger.warn(
          "Patreon group membership callback failed for new user #{user.id} with error: #{e}.\n\n #{e.backtrace.join("\n")}",
        )
      end
    end
  end

  AdminDetailedUserSerializer.define_method(:patreon_patron_record) do
    @patreon_patron_record ||= Patreon::Patron.patron_for_user(object)
  end
  AdminDetailedUserSerializer.send(:private, :patreon_patron_record)

  Patreon::USER_DETAIL_FIELDS.each do |attribute|
    add_to_serializer(
      :admin_detailed_user,
      "patreon_#{attribute}".to_sym,
      include_condition: -> do
        SiteSetting.patreon_enabled &&
          Patreon::Patron.attr(attribute, object, patreon_patron_record).present? &&
          (attribute != "amount_cents" || scope.is_admin?)
      end,
    ) { Patreon::Patron.attr(attribute, object, patreon_patron_record) }
  end

  add_to_serializer(
    :admin_detailed_user,
    :patreon_email_exists,
    include_condition: -> do
      SiteSetting.patreon_enabled &&
        Patreon::Patron.attr("email", object, patreon_patron_record).present?
    end,
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

# frozen_string_literal: true

# name: discourse-microsoft-auth
# about: Enable Login via Microsoft Identity Platform (Office 365 / Microsoft 365 Accounts)
# meta_topic_id: 51731
# version: 2.0
# authors: Matthew Wilkin
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-microsoft-auth

require_relative "lib/omniauth-microsoft365"
require_relative "lib/microsoft_authenticator"

enabled_site_setting :microsoft_auth_enabled

register_svg_icon "fab-microsoft"

auth_provider authenticator: MicrosoftAuthenticator.new, icon: "fab-microsoft"

# frozen_string_literal: true

require "securerandom"
%w[admin-account user-account].each do |username|
  user = User.find_by_username(username)
  user ||=
    User.create!(
      username: username,
      email: "#{username}@localhost.invalid",
      password: SecureRandom.base64(36),
      active: true,
      approved: true,
    )
  user.update!(active: true, approved: true)
  user.grant_admin! if username == "admin-account" && !user.admin?
  user.activate
  user.email_tokens.update_all(confirmed: true)
end
SiteSetting.force_hostname = ENV.fetch("PREVIEW_HOST", "")
SiteSetting.force_https = ENV["PREVIEW_HOST"].present?
SiteSetting.port = ENV["PREVIEW_HOST"].present? ? "443" : "3000"
SiteSetting.title = "Card #{ENV.fetch("CARD_ID")} preview"

# frozen_string_literal: true

Fabricator(:single_sign_on_record) do
  user
  external_id { sequence(:external_id) { |i| "ext_#{i}" } }
  external_username { sequence(:username) { |i| "bruce#{i}" } }
  external_email { sequence(:email) { |i| "bruce#{i}@wayne.com" } }
  last_payload { sequence(:last_payload) { |i| "nonce=#{i}1870a940bbcbb46f06880ed338d58a07&name=" } }
end

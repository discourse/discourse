# frozen_string_literal: true

Fabricator(:push_subscription) do
  user
  data '{"endpoint": "https://fcm.googleapis.com/fcm/send/abc","keys": {"p256dh": "BJpN7S_sh_RX5atymPB7J1","auth": "5M-xiXhbcFhkkw3YE7uIK"}}'
end

Fabricator(:bound_push_subscription, from: :push_subscription) do
  user_auth_token { |attrs| UserAuthToken.generate!(user_id: attrs[:user].id) }
end

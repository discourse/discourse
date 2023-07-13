# frozen_string_literal: true

Fabricator(:push_subscription) do
  user
  data '{"endpoint": "https://example.com/send","keys": {"p256dh": "BJpN7S_sh_RX5atymPB7J1","auth": "5M-xiXhbcFhkkw3YE7uIK"}}'
end

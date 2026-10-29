# frozen_string_literal: true

Fabricator(:push_subscription) do
  user
  data do
    {
      endpoint: sequence(:push_endpoint) { |number| "https://example.com/send/#{number}" },
      keys: {
        p256dh: "BJpN7S_sh_RX5atymPB7J1",
        auth: "5M-xiXhbcFhkkw3YE7uIK",
      },
    }.to_json
  end
end

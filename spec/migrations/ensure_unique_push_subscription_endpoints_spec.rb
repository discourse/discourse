# frozen_string_literal: true

require Rails.root.join("db/migrate/20261025182121_ensure_unique_push_subscription_endpoints.rb")

RSpec.describe EnsureUniquePushSubscriptionEndpoints do
  fab!(:user)
  fab!(:other_user, :user)

  it "keeps the newest owner of each endpoint and prevents duplicate ownership" do
    ActiveRecord::Base.connection.remove_index(
      :push_subscriptions,
      name: "index_push_subscriptions_on_endpoint",
    )
    old_data = {
      endpoint: "https://push.example/subscription",
      keys: {
        auth: "YQ",
        p256dh: "old-key",
      },
    }
    new_data = {
      keys: {
        p256dh: "new-key",
        auth: "YQ==",
      },
      endpoint: "https://PUSH.example:443/a/../%73ubscription#ignored",
    }
    PushSubscription.create!(user: user, data: old_data.to_json)
    newest = PushSubscription.create!(user: other_user, data: new_data.to_json)
    unrelated = PushSubscription.create!(user: user, data: { endpoint: "other-endpoint" }.to_json)

    described_class.new.up

    expect(PushSubscription.all).to contain_exactly(newest, unrelated)
    expect(newest.reload.parsed_data["endpoint"]).to eq(old_data[:endpoint])
    expect do
      PushSubscription.transaction(requires_new: true) do
        PushSubscription.create!(user: user, data: old_data.to_json)
      end
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end

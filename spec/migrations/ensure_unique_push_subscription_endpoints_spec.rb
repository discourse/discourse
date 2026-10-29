# frozen_string_literal: true

require Rails.root.join("db/migrate/20261025182121_ensure_unique_push_subscription_endpoints.rb")

RSpec.describe EnsureUniquePushSubscriptionEndpoints do
  fab!(:user)
  fab!(:other_user, :user)

  it "removes malformed legacy endpoints while retaining valid subscriptions" do
    ActiveRecord::Base.connection.remove_index(
      :push_subscriptions,
      name: "index_push_subscriptions_on_endpoint",
    )
    [nil, "", " ", "#fragment", 1, false, true, [], {}, "https://exa mple.com"].each do |endpoint|
      PushSubscription.create!(user: user, data: { endpoint: endpoint }.to_json)
    end
    PushSubscription.create!(user: user, data: { keys: { auth: "key" } }.to_json)
    retained = Fabricate(:push_subscription, user: user)

    described_class.new.up

    expect(PushSubscription.all).to contain_exactly(retained)
  end

  it "removes oversized legacy endpoints before building the unique index" do
    ActiveRecord::Base.connection.remove_index(
      :push_subscriptions,
      name: "index_push_subscriptions_on_endpoint",
    )
    oversized_endpoint = "https://push.example/#{SecureRandom.hex(4096)}"
    PushSubscription.create!(user: user, data: { endpoint: oversized_endpoint }.to_json)
    PushSubscription.create!(
      user: user,
      data: { endpoint: "https://push.example/#{"é" * 400}" }.to_json,
    )
    endpoint = "https://push.example/".ljust(2048, "a")
    retained = PushSubscription.create!(user: user, data: { endpoint: endpoint }.to_json)

    described_class.new.up

    expect(PushSubscription.all).to contain_exactly(retained)
    expect do
      PushSubscription.transaction(requires_new: true) do
        PushSubscription.create!(user: other_user, data: retained.data)
      end
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

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

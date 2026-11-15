# frozen_string_literal: true

require Rails.root.join("db/migrate/20261106224349_add_endpoint_index_to_push_subscriptions.rb")

RSpec.describe AddEndpointIndexToPushSubscriptions do
  self.use_transactional_tests = false

  after { PushSubscription.delete_all }

  it "removes legacy rows that cannot be cast to jsonb" do
    PushSubscription.create!(
      user_id: -1,
      data: { endpoint: "https://push.example/a\u0000b" }.to_json,
    )
    retained =
      PushSubscription.create!(user_id: -1, data: { endpoint: "https://push.example/b" }.to_json)

    described_class.new.up

    expect(PushSubscription.all).to contain_exactly(retained)
  end
end

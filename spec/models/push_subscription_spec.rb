# frozen_string_literal: true

RSpec.describe PushSubscription do
  describe ".with_endpoint" do
    it "finds subscriptions through the partial endpoint index" do
      DB.exec("SET LOCAL enable_seqscan = off")
      plan =
        DB.query_single("EXPLAIN #{described_class.with_endpoint("https://push.test/1").to_sql}")

      expect(plan.first).to include("index_push_subscriptions_on_endpoint")
    end
  end
end

# frozen_string_literal: true

RSpec.describe Jobs::DeliverUntrustedPushNotifications do
  fab!(:user)
  fab!(:other_user, :user)

  let(:message) { { title: "title", body: "body", url: "/t/1/2" } }

  def subscribe(subscriber, endpoint)
    Fabricate(
      :push_subscription,
      user: subscriber,
      data: { endpoint: endpoint, keys: { p256dh: "p256dh", auth: "auth" } }.to_json,
    )
  end

  def track_deliveries
    delivered = []
    WebPush.stubs(:payload_send).with { |args| delivered << args[:endpoint] }
    delivered
  end

  before do
    subscribe(user, "https://push.example.org/user")
    subscribe(other_user, "https://push.example.org/other")
  end

  describe ".add" do
    it "schedules a drain of the queue" do
      expect_enqueued_with(job: :deliver_untrusted_push_notifications) do
        described_class.add(user_id: user.id, message: message)
      end
    end
  end

  describe "#execute" do
    it "delivers every queued notification" do
      delivered = track_deliveries
      described_class.add(user_id: user.id, message: message)
      described_class.add(user_id: other_user.id, message: message)

      described_class.new.execute({})

      expect(delivered).to contain_exactly(
        "https://push.example.org/user",
        "https://push.example.org/other",
      )
    end

    it "leaves the queue to the job holding this site's lock" do
      delivered = track_deliveries
      described_class.add(user_id: user.id, message: message)
      Discourse.redis.set(described_class::LOCK_KEY, "other", ex: 60)

      described_class.new.execute({})
      expect(delivered).to be_empty

      Discourse.redis.del(described_class::LOCK_KEY)
      described_class.new.execute({})
      expect(delivered).to contain_exactly("https://push.example.org/user")
    end

    it "skips notifications that waited longer than the maximum delay" do
      delivered = track_deliveries
      described_class.add(user_id: user.id, message: message)
      freeze_time(31.minutes.from_now)

      described_class.new.execute({})

      expect(delivered).to be_empty
    end

    it "keeps draining after a delivery fails" do
      delivered = []
      WebPush
        .stubs(:payload_send)
        .with { |args| delivered << args[:endpoint] }
        .raises(StandardError)
        .then
        .returns(nil)
      described_class.add(user_id: user.id, message: message)
      described_class.add(user_id: other_user.id, message: message)

      described_class.new.execute({})

      expect(delivered).to contain_exactly(
        "https://push.example.org/user",
        "https://push.example.org/other",
      )
    end

    it "schedules another drain when it stops with notifications still queued" do
      described_class.add(user_id: user.id, message: message)

      stub_const(described_class, :MAX_RUN_DURATION, 0) do
        expect_enqueued_with(job: :deliver_untrusted_push_notifications) do
          described_class.new.execute({})
        end
      end
    end
  end
end

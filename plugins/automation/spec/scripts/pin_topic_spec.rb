# frozen_string_literal: true

describe "PinTopic" do
  fab!(:user)
  fab!(:category) { Fabricate(:category, user: user) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:automation) { Fabricate(:automation, script: DiscourseAutomation::Scripts::PIN_TOPIC) }

  before do
    automation.upsert_field!("pinnable_topic", "text", { value: topic.id }, target: "script")
  end

  context "when not pinned globally" do
    it "works" do
      expect(topic.pinned_at).to be_nil

      automation.trigger!
      topic.reload

      expect(topic.pinned_at).to be_within_one_minute_of(Time.zone.now)
      expect(topic.pinned_globally).to be_falsey
      expect(topic.pinned_until).to be_nil
    end
  end

  context "when pinned globally" do
    before { automation.upsert_field!("pinned_globally", "boolean", { value: true }) }

    it "works" do
      expect(topic.pinned_at).to be_nil

      automation.trigger!
      topic.reload

      expect(topic.pinned_at).to be_within_one_minute_of(Time.zone.now)
      expect(topic.pinned_globally).to be_truthy
      expect(topic.pinned_until).to be_nil
    end
  end

  describe "pinned until" do
    before do
      freeze_time
      automation.upsert_field!("pinned_until", "date_time", { value: 10.days.from_now })
    end

    it "works" do
      expect(topic.pinned_at).to be_nil

      automation.trigger!

      # expect_enqueued_with is sometimes failing with float precision
      job = Jobs::UnpinTopic.jobs.last
      expect(job["args"][0]["topic_id"]).to eq(topic.id)
      expect(Time.at(job["at"])).to be_within_one_minute_of(10.days.from_now)

      topic.reload

      expect(topic.pinned_at).to be_within_one_minute_of(Time.zone.now)
      expect(topic.pinned_globally).to be_falsey
      expect(topic.pinned_until).to be_within_one_minute_of(10.days.from_now)
    end
  end
end

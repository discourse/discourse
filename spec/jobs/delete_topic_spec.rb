require 'rails_helper'

describe Jobs::DeleteTopic do
  let(:admin) { Fabricate(:admin) }

  let(:topic) do
    Fabricate(:topic_timer, user: admin).topic
  end

  let(:first_post) { create_post(topic: topic) }

  before do
    SiteSetting.queue_jobs = true
  end

  it "can delete a topic" do
    first_post

    Timecop.freeze(2.hours.from_now) do
      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
      expect(topic.reload).to be_trashed
      expect(first_post.reload).to be_trashed
      expect(topic.reload.public_topic_timer).to eq(nil)
    end
  end

  it "should do nothing if topic is already deleted" do
    first_post
    topic.trash!
    Timecop.freeze(2.hours.from_now) do
      Topic.any_instance.expects(:trash!).never
      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
    end
  end

  it "should do nothing if it's too early" do
    t = Fabricate(:topic_timer, user: admin, execute_at: 5.hours.from_now).topic
    create_post(topic: t)
    Timecop.freeze(4.hours.from_now) do
      described_class.new.execute(topic_timer_id: t.public_topic_timer.id)
      expect(t.reload).to_not be_trashed
    end
  end

  describe "user isn't authorized to delete topics" do
    let(:topic) {
      Fabricate(:topic,
        topic_timers: [Fabricate(:topic_timer, user: Fabricate(:user))]
      )
    }

    it "shouldn't delete the topic" do
      create_post(topic: topic)
      Timecop.freeze(2.hours.from_now) do
        described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
        expect(topic.reload).to_not be_trashed
      end
    end
  end

end

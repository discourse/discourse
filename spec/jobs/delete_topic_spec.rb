require 'rails_helper'

describe Jobs::DeleteTopic do
  let(:admin) { Fabricate(:admin) }

  let(:topic) do
    Fabricate(:topic,
      topic_status_updates: [Fabricate(:topic_status_update, user: admin)]
    )
  end

  let(:first_post) { create_post(topic: topic) }

  before do
    SiteSetting.queue_jobs = true
  end

  it "can close a topic" do
    first_post
    Timecop.freeze(2.hours.from_now) do
      described_class.new.execute(topic_status_update_id: topic.topic_status_update.id)
      expect(topic.reload).to be_trashed
      expect(first_post.reload).to be_trashed
    end
  end

  it "should do nothing if topic is already deleted" do
    first_post
    topic.trash!
    Timecop.freeze(2.hours.from_now) do
      Topic.any_instance.expects(:trash!).never
      described_class.new.execute(topic_status_update_id: topic.topic_status_update.id)
    end
  end

  it "should do nothing if it's too early" do
    t = Fabricate(:topic,
      topic_status_updates: [Fabricate(:topic_status_update, user: admin, execute_at: 5.hours.from_now)]
    )
    create_post(topic: t)
    Timecop.freeze(4.hours.from_now) do
      described_class.new.execute(topic_status_update_id: t.topic_status_update.id)
      expect(t.reload).to_not be_trashed
    end
  end

  describe "user isn't authorized to delete topics" do
    let(:topic) {
      Fabricate(:topic,
        topic_status_updates: [Fabricate(:topic_status_update, user: Fabricate(:user))]
      )
    }

    it "shouldn't delete the topic" do
      create_post(topic: topic)
      Timecop.freeze(2.hours.from_now) do
        described_class.new.execute(topic_status_update_id: topic.topic_status_update.id)
        expect(topic.reload).to_not be_trashed
      end
    end
  end

end

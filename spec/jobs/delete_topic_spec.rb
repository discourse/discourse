require 'rails_helper'

describe Jobs::DeleteTopic do
  let(:admin) { Fabricate(:admin) }

  let(:topic) do
    Fabricate(:topic_timer, user: admin).topic
  end

  let(:first_post) { create_post(topic: topic) }

  it "can delete a topic" do
    first_post

    freeze_time (2.hours.from_now)

    described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
    expect(topic.reload).to be_trashed
    expect(first_post.reload).to be_trashed
    expect(topic.reload.public_topic_timer).to eq(nil)

  end

  it "should do nothing if topic is already deleted" do
    first_post
    topic.trash!

    freeze_time 2.hours.from_now

    Topic.any_instance.expects(:trash!).never
    described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
  end

  it "should do nothing if it's too early" do
    t = Fabricate(:topic_timer, user: admin, execute_at: 5.hours.from_now).topic
    create_post(topic: t)

    freeze_time 4.hours.from_now

    described_class.new.execute(topic_timer_id: t.public_topic_timer.id)
    expect(t.reload).to_not be_trashed
  end

  describe "user isn't authorized to delete topics" do
    let(:topic) {
      Fabricate(:topic_timer, user: Fabricate(:user)).topic
    }

    it "shouldn't delete the topic" do
      create_post(topic: topic)

      freeze_time 2.hours.from_now

      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
      expect(topic.reload).to_not be_trashed
    end
  end

end

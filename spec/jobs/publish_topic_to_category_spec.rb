# frozen_string_literal: true

RSpec.describe Jobs::PublishTopicToCategory do
  fab!(:category)
  fab!(:another_category, :category)

  let(:topic) do
    topic = Fabricate(:topic, category: category)

    Fabricate(
      :topic_timer,
      status_type: TopicTimer.types[:publish_to_category],
      category_id: another_category.id,
      topic: topic,
      execute_at: 1.minute.ago,
      created_at: 5.minutes.ago,
    )

    Fabricate(:post, topic: topic, user: topic.user)

    topic
  end

  describe "when topic has been deleted" do
    it "should not publish the topic to the new category" do
      created_at = freeze_time 1.hour.ago
      topic

      freeze_time 1.hour.from_now
      topic.trash!

      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)

      topic.reload
      expect(topic.category).to eq(category)
      expect(topic.created_at).to eq_time(created_at)
    end
  end

  it "should publish the topic to the new category" do
    freeze_time 1.hour.ago do
      topic.update!(visible: false)
    end

    now = freeze_time

    message =
      MessageBus
        .track_publish { described_class.new.execute(topic_timer_id: topic.public_topic_timer.id) }
        .find { |m| Hash === m.data && m.data.key?(:reload_topic) && m.data.key?(:refresh_stream) }

    topic.reload
    expect(topic.category).to eq(another_category)
    expect(topic.visible).to eq(true)
    expect(topic.public_topic_timer).to eq(nil)
    expect(message.channel).to eq("/topic/#{topic.id}")

    %w[created_at bumped_at updated_at last_posted_at].each do |attribute|
      expect(topic.public_send(attribute)).to eq_time(now)
    end
  end

  describe "when topic is a private message" do
    it "should publish the topic to the new category" do
      freeze_time 1.hour.ago do
        expect { topic.convert_to_private_message(Discourse.system_user) }.to change {
          topic.private_message?
        }.to(true)
      end

      topic.allowed_users << topic.public_topic_timer.user

      now = freeze_time

      messages =
        MessageBus.track_publish do
          described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
        end

      expect(messages.any? { |m| m.data[:reload_topic] && m.data[:refresh_stream] }).to eq(true)

      topic.reload
      expect(topic.category).to eq(another_category)
      expect(topic.visible).to eq(true)
      expect(topic.private_message?).to eq(false)

      %w[created_at bumped_at updated_at last_posted_at].each do |attribute|
        expect(topic.public_send(attribute)).to eq_time(now)
      end
    end

    it "does nothing if the user can't see the PM" do
      non_participant_TL4_user = Fabricate(:trust_level_4)
      topic.convert_to_private_message(Discourse.system_user)
      timer = topic.public_topic_timer
      timer.update!(user: non_participant_TL4_user)

      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)

      topic.reload
      expect(topic.private_message?).to eq(true)
      expect(topic.category).not_to eq(another_category)
    end

    it "works if the user can see the PM" do
      tl4_user = Fabricate(:trust_level_4)
      topic.convert_to_private_message(Discourse.system_user)

      topic.allowed_users << tl4_user

      timer = topic.public_topic_timer
      timer.update!(user: tl4_user)

      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)

      topic.reload
      expect(topic.private_message?).to eq(false)
      expect(topic.category).to eq(another_category)
    end
  end

  describe "when new category has a default auto-close" do
    it "should apply the auto-close timer upon publishing" do
      freeze_time

      another_category.update!(auto_close_hours: 5)
      topic

      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)

      topic.reload
      topic_timer = topic.public_topic_timer
      expect(topic.category).to eq(another_category)
      expect(topic_timer.status_type).to eq(TopicTimer.types[:close])
      expect(topic_timer.execute_at).to be_within_one_second_of(5.hours.from_now)
    end
  end
end

require 'rails_helper'

describe TopicConverter do

  context 'convert_to_public_topic' do
    let(:admin) { Fabricate(:admin) }
    let(:author) { Fabricate(:user) }
    let(:private_message) { Fabricate(:private_message_topic, user: author) }

    context 'success' do
      it "converts private message to regular topic" do
        topic = private_message.convert_to_public_topic(admin)
        expect(topic).to be_valid
        expect(topic.archetype).to eq("regular")
      end

      it "updates user stats" do
        topic_user = TopicUser.create!(user_id: author.id, topic_id: private_message.id, posted: true)
        expect(private_message.user.user_stat.topic_count).to eq(0)
        private_message.convert_to_public_topic(admin)
        expect(private_message.reload.user.user_stat.topic_count).to eq(1)
        expect(topic_user.reload.notification_level).to eq(TopicUser.notification_levels[:watching])
      end
    end
  end

  context 'convert_to_private_message' do
    let(:admin) { Fabricate(:admin) }
    let(:author) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic, user: author) }

    context 'success' do
      it "converts regular topic to private message" do
        private_message = topic.convert_to_private_message(admin)
        expect(private_message).to be_valid
        expect(topic.archetype).to eq("private_message")
      end

      it "updates user stats" do
        Fabricate(:post, topic: topic, user: author)
        topic_user = TopicUser.create!(user_id: author.id, topic_id: topic.id, posted: true)
        author.user_stat.topic_count = 1
        author.user_stat.save
        expect(topic.user.user_stat.topic_count).to eq(1)
        topic.convert_to_private_message(admin)

        expect(topic.reload.topic_allowed_users.where(user_id: author.id).count).to eq(1)
        expect(topic.reload.user.user_stat.topic_count).to eq(0)
        expect(topic_user.reload.notification_level).to eq(TopicUser.notification_levels[:watching])
      end
    end

    context 'topic has replies' do
      before do
        @replied_user = Fabricate(:coding_horror)
        create_post(topic: topic, user: @replied_user)
        topic.reload
      end

      it 'adds users who replied to topic in Private Message' do
        topic.convert_to_private_message(admin)

        expect(topic.reload.topic_allowed_users.where(user_id: @replied_user.id).count).to eq(1)
        expect(topic.reload.user.user_stat.post_count).to eq(0)
      end
    end
  end
end

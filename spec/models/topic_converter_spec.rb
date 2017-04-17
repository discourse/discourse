require 'rails_helper'

describe TopicConverter do

  context 'convert_to_public_topic' do
    let(:admin) { Fabricate(:admin) }
    let(:author) { Fabricate(:user) }
    let(:category) { Fabricate(:category) }
    let(:private_message) { Fabricate(:private_message_topic, user: author) }

    context 'success' do
      it "converts private message to regular topic" do
        SiteSetting.allow_uncategorized_topics = true
        topic = described_class.new(private_message, admin).convert_to_public_topic
        topic.reload

        expect(topic).to be_valid
        expect(topic.archetype).to eq("regular")
        expect(topic.category_id).to eq(SiteSetting.uncategorized_category_id)
      end

      describe 'when uncategorized category is not allowed' do
        before do
          SiteSetting.allow_uncategorized_topics = false
          category.update!(read_restricted: false)
        end

        it 'should convert private message into the right category' do
          topic = described_class.new(private_message, admin).convert_to_public_topic
          topic.reload

          expect(topic).to be_valid
          expect(topic.archetype).to eq("regular")
          expect(topic.category_id).to eq(category.id)
        end
      end

      describe 'when a custom category_id is given' do
        it 'should convert private message into the right category' do
          topic = described_class.new(private_message, admin).convert_to_public_topic(category.id)

          expect(topic.reload.category).to eq(category)
        end
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

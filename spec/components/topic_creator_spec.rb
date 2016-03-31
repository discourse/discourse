require 'rails_helper'

describe TopicCreator do

  let(:user)      { Fabricate(:user, trust_level: TrustLevel[2]) }
  let(:moderator) { Fabricate(:moderator) }
  let(:admin)     { Fabricate(:admin) }

  let(:valid_attrs) { Fabricate.attributes_for(:topic) }
  let(:pm_valid_attrs)  { {raw: 'this is a new post', title: 'this is a new title', archetype: Archetype.private_message, target_usernames: moderator.username} }

  describe '#create' do
    context 'topic success cases' do
      before do
        TopicCreator.any_instance.expects(:save_topic).returns(true)
        TopicCreator.any_instance.expects(:watch_topic).returns(true)
        SiteSetting.stubs(:allow_duplicate_topic_titles?).returns(true)
      end

      it "should be possible for an admin to create a topic" do
        expect(TopicCreator.create(admin, Guardian.new(admin), valid_attrs)).to be_valid
      end

      it "should be possible for a moderator to create a topic" do
        expect(TopicCreator.create(moderator, Guardian.new(moderator), valid_attrs)).to be_valid
      end

      context 'regular user' do
        before { SiteSetting.stubs(:min_trust_to_create_topic).returns(TrustLevel[0]) }

        it "should be possible for a regular user to create a topic" do
          expect(TopicCreator.create(user, Guardian.new(user), valid_attrs)).to be_valid
        end

        it "should be possible for a regular user to create a topic with blank auto_close_time" do
          expect(TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(auto_close_time: ''))).to be_valid
        end

        it "ignores auto_close_time without raising an error" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(auto_close_time: '24'))
          expect(topic).to be_valid
          expect(topic.auto_close_at).to eq(nil)
        end

        it "category name is case insensitive" do
          category = Fabricate(:category, name: "Neil's Blog")
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(category: "neil's blog"))
          expect(topic).to be_valid
          expect(topic.category).to eq(category)
        end
      end
    end

    context 'private message' do

      context 'success cases' do
        before do
          TopicCreator.any_instance.expects(:save_topic).returns(true)
          TopicCreator.any_instance.expects(:watch_topic).returns(true)
          SiteSetting.stubs(:allow_duplicate_topic_titles?).returns(true)
        end

        it "should be possible for a regular user to send private message" do
          expect(TopicCreator.create(user, Guardian.new(user), pm_valid_attrs)).to be_valid
        end

        it "min_trust_to_create_topic setting should not be checked when sending private message" do
          SiteSetting.min_trust_to_create_topic = TrustLevel[4]
          expect(TopicCreator.create(user, Guardian.new(user), pm_valid_attrs)).to be_valid
        end
      end

      context 'failure cases' do
        it "min_trust_to_send_messages setting should be checked when sending private message" do
          SiteSetting.min_trust_to_send_messages = TrustLevel[4]
          expect(-> { TopicCreator.create(user, Guardian.new(user), pm_valid_attrs) }).to raise_error(ActiveRecord::Rollback)
        end
      end
    end
  end
end

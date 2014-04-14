require 'spec_helper'

describe TopicCreator do

  let(:user)      { Fabricate(:user) }
  let(:moderator) { Fabricate(:moderator) }
  let(:admin)     { Fabricate(:admin) }

  let(:valid_attrs) { Fabricate.attributes_for(:topic) }

  describe '#create' do
    context 'success cases' do
      before do
        TopicCreator.any_instance.expects(:save_topic).returns(true)
        TopicCreator.any_instance.expects(:watch_topic).returns(true)
        SiteSetting.stubs(:allow_duplicate_topic_titles?).returns(true)
      end

      it "should be possible for an admin to create a topic" do
        TopicCreator.create(admin, Guardian.new(admin), valid_attrs).should be_valid
      end

      it "should be possible for a moderator to create a topic" do
        TopicCreator.create(moderator, Guardian.new(moderator), valid_attrs).should be_valid
      end

      context 'regular user' do
        before { SiteSetting.stubs(:min_trust_to_create_topic).returns(TrustLevel.levels[:newuser]) }

        it "should be possible for a regular user to create a topic" do
          TopicCreator.create(user, Guardian.new(user), valid_attrs).should be_valid
        end

        it "should be possible for a regular user to create a topic with blank auto_close_time" do
          TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(auto_close_time: '')).should be_valid
        end

        it "ignores auto_close_time without raising an error" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(auto_close_time: '24'))
          topic.should be_valid
          topic.auto_close_at.should be_nil
        end
      end
    end
  end

end

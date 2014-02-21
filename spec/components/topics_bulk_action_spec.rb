require 'spec_helper'
require_dependency 'topics_bulk_action'

describe TopicsBulkAction do

  describe "invalid operation" do
    let(:user) { Fabricate.build(:user) }

    it "raises an error with an invalid operation" do
      tba = TopicsBulkAction.new(user, [1], type: 'rm_root')
      -> { tba.perform! }.should raise_error(Discourse::InvalidParameters)
    end
  end

  describe "change_category" do
    let(:topic) { Fabricate(:topic) }
    let(:category) { Fabricate(:category) }

    context "when the user can edit the topic" do
      it "changes the category and returns the topic_id" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_name: category.name)
        topic_ids = tba.perform!
        topic_ids.should == [topic.id]
        topic.reload
        topic.category.should == category
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't change the category" do
        Guardian.any_instance.expects(:can_edit?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_name: category.name)
        topic_ids = tba.perform!
        topic_ids.should == []
        topic.reload
        topic.category.should_not == category
      end
    end
  end

  describe "reset_read" do
    let(:topic) { Fabricate(:topic) }

    it "delegates to PostTiming.destroy_for" do
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'reset_read')
      PostTiming.expects(:destroy_for).with(topic.user_id, [topic.id])
      topic_ids = tba.perform!
    end
  end

  describe "change_notification_level" do
    let(:topic) { Fabricate(:topic) }

    context "when the user can see the topic" do
      it "updates the notification level" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_notification_level', notification_level_id: 2)
        topic_ids = tba.perform!
        topic_ids.should == [topic.id]
        TopicUser.get(topic, topic.user).notification_level.should == 2
      end
    end

    context "when the user can't see the topic" do
      it "doesn't change the level" do
        Guardian.any_instance.expects(:can_see?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_notification_level', notification_level_id: 2)
        topic_ids = tba.perform!
        topic_ids.should == []
        TopicUser.get(topic, topic.user).should be_blank
      end
    end
  end

  describe "close" do
    let(:topic) { Fabricate(:topic) }

    context "when the user can moderate the topic" do
      it "closes the topic and returns the topic_id" do
        Guardian.any_instance.expects(:can_moderate?).returns(true)
        Guardian.any_instance.expects(:can_create?).returns(true)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'close')
        topic_ids = tba.perform!
        topic_ids.should == [topic.id]
        topic.reload
        topic.should be_closed
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't close the topic" do
        Guardian.any_instance.expects(:can_moderate?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'close')
        topic_ids = tba.perform!
        topic_ids.should be_blank
        topic.reload
        topic.should_not be_closed
      end
    end
  end
end

require 'spec_helper'
require 'topics_bulk_action'

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
      it "doesn't change the category and returns the topic_id" do
        Guardian.any_instance.expects(:can_edit?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_name: category.name)
        topic_ids = tba.perform!
        topic_ids.should == []
        topic.reload
        topic.category.should_not == category
      end
    end

  end
end


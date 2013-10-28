require 'spec_helper'
require_dependency 'post_action'

describe TopicListItemSerializer do

  it "correctly serializes topic" do
    date = Time.zone.now

    topic = Topic.new
    topic.title = "test"
    topic.created_at = date - 2.minutes
    topic.bumped_at = date
    topic.posters = []
    serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

    serialized[:title].should == "test"
    serialized[:bumped].should == true
  end
end

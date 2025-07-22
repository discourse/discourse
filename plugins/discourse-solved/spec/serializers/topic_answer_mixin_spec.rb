# frozen_string_literal: true

require "rails_helper"

describe DiscourseSolved::TopicAnswerMixin do
  let(:topic) { Fabricate(:topic) }
  let(:post) { Fabricate(:post, topic: topic) }
  let(:guardian) { Guardian.new }

  before { Fabricate(:solved_topic, topic: topic, answer_post: post) }

  it "should have true for `has_accepted_answer` field in each serializer" do
    [
      TopicListItemSerializer,
      SearchTopicListItemSerializer,
      SuggestedTopicSerializer,
      UserSummarySerializer::TopicSerializer,
    ].each do |serializer|
      json = serializer.new(topic, scope: guardian, root: false).as_json
      expect(json[:has_accepted_answer]).to be_truthy
    end
  end
end

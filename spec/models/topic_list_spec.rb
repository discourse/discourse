require 'rails_helper'

describe TopicList do
  let!(:topic) { Fabricate(:topic) }
  let(:user) { topic.user }
  let(:topic_list) { TopicList.new("liked", user, [topic]) }

  after do
    TopicList.preloaded_custom_fields.clear
  end

  describe ".preloaded_custom_fields" do
    it "should return a unique set of values" do
      TopicList.preloaded_custom_fields << "test"
      TopicList.preloaded_custom_fields << "test"
      TopicList.preloaded_custom_fields << "apple"

      expect(TopicList.preloaded_custom_fields).to eq(Set.new(%w{test apple}))
    end
  end

  context "DiscourseTagging enabled" do
    before do
      SiteSetting.tagging_enabled = true
    end

    after do
      SiteSetting.tagging_enabled = false
    end

    it "should add tags to preloaded custom fields" do
      expect(topic_list.preloaded_custom_fields).to eq(Set.new([DiscourseTagging::TAGS_FIELD_NAME]))
    end
  end
end

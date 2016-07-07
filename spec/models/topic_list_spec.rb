require 'rails_helper'

describe TopicList do
  let!(:topic) { Fabricate(:topic) }
  let(:user) { topic.user }
  let(:topic_list) { TopicList.new("liked", user, [topic]) }

  before do
    TopicList.preloaded_custom_fields.clear
  end

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

  describe '#tags' do
    let(:tag) { Fabricate(:tag, topics: [topic]) }
    let(:other_tag) { Fabricate(:tag, topics: [topic]) }

    it 'should return the right tags' do
      output = [tag.name, other_tag.name]
      expect(topic_list.tags.sort).to eq(output.sort)
    end

    describe 'when topic list is filtered by category' do
      let(:category) { Fabricate(:category) }
      let(:topic) { Fabricate(:topic, category: category) }
      let(:tag) { Fabricate(:tag, topics: [topic], categories: [category]) }
      let(:topic_list) { TopicList.new('latest', topic.user, [topic], { category: category.id, category_id: category.id }) }

      it 'should only return tags allowed in the category' do
        other_tag
        output = [tag.name]

        expect(topic_list.tags).to eq(output)
      end
    end
  end
end

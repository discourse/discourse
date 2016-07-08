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
    it 'should return the right tags' do
      tag = Fabricate(:tag, topics: [topic])
      other_tag = Fabricate(:tag, topics: [topic], name: "use-anywhere")
      output = [tag.name, other_tag.name]
      expect(topic_list.tags.sort).to eq(output.sort)
    end

    describe 'when there are tags restricted to a category' do
      let!(:category) { Fabricate(:category) }
      let!(:topic) { Fabricate(:topic, category: category) }
      let!(:other_topic) { Fabricate(:topic) } # uncategorized
      let!(:tag) { Fabricate(:tag, topics: [topic], categories: [category], name: "category-tag") }
      let!(:other_tag) { Fabricate(:tag, topics: [topic], name: "use-anywhere") }
      let(:topic_list) { TopicList.new('latest', topic.user, [topic], { category: category.id, category_id: category.id }) }

      it 'should only return tags allowed in the category' do
        expect(topic_list.tags).to eq([tag.name])
      end

      it "with no category, should return all tags" do
        expect(TopicList.new('latest', other_topic.user, [other_topic]).tags.sort).to eq([tag.name, other_tag.name].sort)
      end

      it "with another category with no tags, should return exclude tags restricted to other categories" do
        other_category = Fabricate(:category)
        topic3 = Fabricate(:topic, category: other_category)
        list = TopicList.new('latest', topic3.user, [topic3], { category: other_category.id, category_id: other_category.id })
        expect(list.tags).to eq([other_tag.name])
      end
    end
  end
end

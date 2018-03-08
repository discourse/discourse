require 'rails_helper'

describe TopicList do
  let!(:topic) {
    t = Fabricate(:topic)
    t.allowed_user_ids = [t.user.id]
    t
  }

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

  context "preload" do
    it "allows preloading of data" do
      preloaded_topic = false
      preloader = lambda do |topics, topic_list|
        expect(TopicList === topic_list).to eq(true)
        expect(topics.length).to eq(1)
        preloaded_topic = true
      end

      TopicList.on_preload(&preloader)

      topic_list.topics
      expect(preloaded_topic).to eq(true)

      TopicList.cancel_preload(&preloader)
    end
  end

  describe '#top_tags' do
    it 'should return the right tags' do
      tag = Fabricate(:tag, topics: [topic])
      other_tag = Fabricate(:tag, topics: [topic], name: "use-anywhere")
      output = [tag.name, other_tag.name]
      expect(topic_list.top_tags.sort).to eq(output.sort)
    end

    describe 'when there are tags restricted to a category' do
      let!(:category) { Fabricate(:category) }
      let!(:topic) { Fabricate(:topic, category: category) }
      let!(:other_topic) { Fabricate(:topic) } # uncategorized
      let!(:tag) { Fabricate(:tag, topics: [topic], categories: [category], name: "category-tag") }
      let!(:other_tag) { Fabricate(:tag, topics: [topic], name: "use-anywhere") }
      let(:topic_list) { TopicList.new('latest', topic.user, [topic], category: category.id, category_id: category.id) }

      it 'should return tags used in the category' do
        expect(topic_list.top_tags).to eq([tag.name, other_tag.name].sort)
      end

      it "with no category, should return all tags" do
        expect(TopicList.new('latest', other_topic.user, [other_topic]).top_tags.sort).to eq([tag.name, other_tag.name].sort)
      end

      it "with another category with no tags, should return no tags" do
        other_category = Fabricate(:category)
        topic3 = Fabricate(:topic, category: other_category)
        list = TopicList.new('latest', topic3.user, [topic3], category: other_category.id, category_id: other_category.id)
        expect(list.top_tags).to be_empty
      end
    end
  end

  describe '#pm_tags' do
    let(:admin) { Fabricate(:admin) }
    let(:personal_message) { Fabricate(:private_message_topic) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.allow_staff_to_tag_pms = true
      @private_tags = []
      2.times { |i| @private_tags << Fabricate(:tag, topics: [personal_message]) }
    end

    context 'when viewed as normal user' do
      it 'returns no tags' do
        expect(TopicList.new('liked', personal_message.user, [personal_message], show_pm_tags: true).pm_tags).to be_empty
      end
    end

    context 'when viewed as admin' do
      it 'returns pm tags' do
        expect(TopicList.new('liked', admin, [personal_message], show_pm_tags: true).pm_tags).to match_array(@private_tags.map(&:name))
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe TopicList do
  let!(:topic) do
    t = Fabricate(:topic)
    t.allowed_user_ids = [t.user.id]
    t
  end

  let(:user) { topic.user }
  let(:topic_list) { TopicList.new("liked", user, [topic]) }

  before { TopicList.preloaded_custom_fields.clear }

  after { TopicList.preloaded_custom_fields.clear }

  describe ".preloaded_custom_fields" do
    it "should return a unique set of values" do
      TopicList.preloaded_custom_fields << "test"
      TopicList.preloaded_custom_fields << "test"
      TopicList.preloaded_custom_fields << "apple"

      expect(TopicList.preloaded_custom_fields).to eq(Set.new(%w[test apple]))
    end
  end

  describe "preload" do
    it "allows preloading of data" do
      preloaded_topic = false
      preloader =
        lambda do |topics, topic_list|
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

  describe "#load_topics" do
    it "loads additional data for serialization" do
      category_user =
        CategoryUser.create!(
          user: user,
          category: topic.category,
          notification_level: NotificationLevels.all[:regular],
        )

      topic = topic_list.load_topics.first

      expect(topic.category_user_data).to eq(category_user)
    end
  end

  describe "#top_tags" do
    it "should return the right tags" do
      tag = Fabricate(:tag, topics: [topic])
      other_tag = Fabricate(:tag, topics: [topic], name: "use-anywhere")
      output = [tag.name, other_tag.name]
      expect(topic_list.top_tags.sort).to eq(output.sort)
    end

    describe "when there are tags restricted to a category" do
      fab!(:category)
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:other_topic, :topic) # uncategorized
      fab!(:tag) { Fabricate(:tag, topics: [topic], categories: [category], name: "category-tag") }
      fab!(:other_tag) { Fabricate(:tag, topics: [topic], name: "use-anywhere") }
      let(:topic_list) do
        TopicList.new(
          "latest",
          topic.user,
          [topic],
          category: category.id,
          category_id: category.id,
        )
      end

      it "should return tags used in the category" do
        expect(topic_list.top_tags).to eq([tag.name, other_tag.name].sort)
      end

      it "with no category, should return all tags" do
        expect(TopicList.new("latest", other_topic.user, [other_topic]).top_tags.sort).to eq(
          [tag.name, other_tag.name].sort,
        )
      end

      it "with another category with no tags, should return no tags" do
        other_category = Fabricate(:category)
        topic3 = Fabricate(:topic, category: other_category)
        list =
          TopicList.new(
            "latest",
            topic3.user,
            [topic3],
            category: other_category.id,
            category_id: other_category.id,
          )
        expect(list.top_tags).to be_empty
      end
    end
  end

  describe "#preload_key" do
    let(:category) { Fabricate(:category) }
    let(:tag) { Fabricate(:tag) }

    it "returns topic_list" do
      topic_list = TopicList.new("latest", nil, nil, category: category, category_id: category.id)
      expect(topic_list.preload_key).to eq("topic_list")
    end
  end
end

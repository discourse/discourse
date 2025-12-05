# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::MostViewedTags do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:tag_1) { Fabricate(:tag, name: "ruby") }
  fab!(:tag_2) { Fabricate(:tag, name: "javascript") }
  fab!(:tag_3) { Fabricate(:tag, name: "python") }
  fab!(:tag_4) { Fabricate(:tag, name: "golang") }
  fab!(:tag_5) { Fabricate(:tag, name: "rust") }

  fab!(:topic_1, :topic)
  fab!(:topic_2, :topic)
  fab!(:topic_3, :topic)
  fab!(:topic_4, :topic)
  fab!(:topic_5, :topic)

  before do
    SiteSetting.tagging_enabled = true

    topic_1.tags = [tag_1]
    topic_2.tags = [tag_1]
    topic_3.tags = [tag_2]
    topic_4.tags = [tag_3]
    topic_5.tags = [tag_4]
  end

  describe ".call" do
    it "returns top 4 most viewed tags ordered by view count" do
      # Tag 1 (ruby): 2 views (2 different topics)
      TopicViewItem.add(topic_1.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      TopicViewItem.add(topic_2.id, "127.0.0.2", user.id, Date.new(2021, 4, 20))

      # Tag 2 (javascript): 1 view
      TopicViewItem.add(topic_3.id, "127.0.0.3", user.id, Date.new(2021, 5, 10))

      # Tag 3 (python): 1 view
      TopicViewItem.add(topic_4.id, "127.0.0.4", user.id, Date.new(2021, 6, 5))

      # Tag 4 (golang): 3 views (same topic, multiple views)
      TopicViewItem.add(topic_5.id, "127.0.0.5", user.id, Date.new(2021, 7, 1))
      TopicViewItem.add(topic_5.id, "127.0.0.6", user.id, Date.new(2021, 8, 15))
      TopicViewItem.add(topic_5.id, "127.0.0.7", user.id, Date.new(2021, 9, 20))

      # Tag 5 (rust): 0 views

      result = call_report

      expect(result[:data]).to eq(
        [
          { tag_id: tag_1.id, name: "ruby" },
          { tag_id: tag_2.id, name: "javascript" },
          { tag_id: tag_3.id, name: "python" },
          { tag_id: tag_4.id, name: "golang" },
        ],
      )
    end

    it "only includes tags the user can see (no restricted tags)" do
      group = Fabricate(:group)
      tag_group = Fabricate(:tag_group, tags: [tag_5])
      tag_group.permissions = { group.name => TagGroupPermission.permission_types[:full] }
      tag_group.save!

      restricted_topic = Fabricate(:topic)
      restricted_topic.tags = [tag_5]

      TopicViewItem.add(restricted_topic.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))

      result = call_report
      expect(result[:data].map { |t| t[:tag_id] }).not_to include(tag_5.id)
    end

    it "filters by date range" do
      TopicViewItem.add(topic_1.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      TopicViewItem.add(topic_2.id, "127.0.0.2", user.id, Date.new(2020, 12, 31))

      result = call_report

      expect(result[:data].length).to eq(1)
      expect(result[:data].first[:tag_id]).to eq(tag_1.id)
    end

    it "only counts views for the specific user" do
      TopicViewItem.add(topic_1.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      TopicViewItem.add(topic_2.id, "127.0.0.2", other_user.id, Date.new(2021, 4, 20))

      result = call_report

      expect(result[:data].length).to eq(1)
      expect(result[:data].first[:tag_id]).to eq(tag_1.id)
    end

    it "counts distinct topics per tag" do
      multi_tag_topic = Fabricate(:topic)
      multi_tag_topic.tags = [tag_1, tag_2]

      TopicViewItem.add(multi_tag_topic.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      TopicViewItem.add(multi_tag_topic.id, "127.0.0.2", user.id, Date.new(2021, 4, 20))

      result = call_report

      tag_1_data = result[:data].find { |t| t[:tag_id] == tag_1.id }
      tag_2_data = result[:data].find { |t| t[:tag_id] == tag_2.id }
      expect(tag_1_data).not_to be_nil
      expect(tag_2_data).not_to be_nil
    end

    it "returns empty array when no views" do
      result = call_report

      expect(result[:data]).to eq([])
    end
  end
end

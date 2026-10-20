# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::MostViewedTags do
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:tag_1) { Fabricate(:tag, name: "ruby") }
  fab!(:tag_2) { Fabricate(:tag, name: "javascript") }
  fab!(:tag_3) { Fabricate(:tag, name: "python") }
  fab!(:tag_4) { Fabricate(:tag, name: "golang") }
  fab!(:tag_5) { Fabricate(:tag, name: "rust") }

  fab!(:topic_1) { Fabricate(:topic, tags: [tag_1]) }
  fab!(:topic_2) { Fabricate(:topic, tags: [tag_1]) }
  fab!(:topic_3) { Fabricate(:topic, tags: [tag_2]) }
  fab!(:topic_4) { Fabricate(:topic, tags: [tag_3]) }
  fab!(:topic_5) { Fabricate(:topic, tags: [tag_4]) }

  before { SiteSetting.tagging_enabled = true }

  describe ".call" do
    it "returns top 4 most viewed tags ordered by view count" do
      TopicViewItem.add(topic_1.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      TopicViewItem.add(topic_2.id, "127.0.0.2", user.id, Date.new(2021, 4, 20))
      TopicViewItem.add(topic_3.id, "127.0.0.3", user.id, Date.new(2021, 5, 10))
      TopicViewItem.add(topic_4.id, "127.0.0.4", user.id, Date.new(2021, 6, 5))
      TopicViewItem.add(topic_5.id, "127.0.0.5", user.id, Date.new(2021, 7, 1))
      TopicViewItem.add(topic_5.id, "127.0.0.6", user.id, Date.new(2021, 8, 15))
      TopicViewItem.add(topic_5.id, "127.0.0.7", user.id, Date.new(2021, 9, 20))

      result = call_report

      expect(result[:data]).to eq(
        [
          { tag_id: tag_1.id, slug: "ruby", name: "ruby" },
          { tag_id: tag_2.id, slug: "javascript", name: "javascript" },
          { tag_id: tag_3.id, slug: "python", name: "python" },
          { tag_id: tag_4.id, slug: "golang", name: "golang" },
        ],
      )
    end

    it "excludes views of personal messages and restricted categories" do
      private_message = Fabricate(:private_message_topic)
      private_message.tags = [tag_5]
      restricted_topic =
        Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group)))
      restricted_topic.tags = [tag_5]
      [private_message, restricted_topic].each do |topic|
        TopicViewItem.add(topic.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      end

      expect(call_report[:data].map { |tag| tag[:tag_id] }).not_to include(tag_5.id)
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

    it "returns empty array when no views" do
      result = call_report

      expect(result[:data]).to eq([])
    end

    describe "only include tags which anon users (meaning everyone) can view" do
      fab!(:group)
      fab!(:restricted_tag) { Fabricate(:tag, name: "secret") }
      fab!(:restricted_topic, :topic)

      let(:full) { TagGroupPermission.permission_types[:full] }

      before do
        group.add(user)
        restricted_topic.tags = [restricted_tag]
        restricted_topic.save!
      end

      it "excludes tags where user has access but anon does not" do
        tag_group = Fabricate(:tag_group, tags: [restricted_tag])
        tag_group.permissions = [[group, full]]
        tag_group.save!

        TopicViewItem.add(restricted_topic.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
        TopicViewItem.add(topic_1.id, "127.0.0.2", user.id, Date.new(2021, 4, 20))

        result = call_report
        expect(result[:data].map { |t| t[:tag_id] }).to contain_exactly(tag_1.id)
      end
    end
  end

  describe ".filter_for_viewer" do
    it "drops tags that are no longer visible to everyone, even for the owner" do
      report = { data: [tag_1, tag_2].map { |tag| { tag_id: tag.id } } }
      group = Fabricate(:group)
      group.add(user)
      tag_group = Fabricate(:tag_group, tags: [tag_2])
      tag_group.permissions = [[group, TagGroupPermission.permission_types[:full]]]
      tag_group.save!

      filtered = described_class.filter_for_viewer(report, guardian: user.guardian, for_user: user)

      expect(filtered[:data]).to eq([{ tag_id: tag_1.id }])
    end
  end
end

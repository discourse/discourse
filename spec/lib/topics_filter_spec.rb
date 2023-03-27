# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:admin) { Fabricate(:admin) }

  describe "#filter_status" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:closed_topic) { Fabricate(:topic, closed: true) }
    fab!(:archived_topic) { Fabricate(:topic, archived: true) }
    fab!(:deleted_topic_id) { Fabricate(:topic, deleted_at: Time.zone.now).id }

    it "should only return topics that have not been closed or archived when status is `open`" do
      expect(
        TopicsFilter.new(guardian: Guardian.new).filter_status(status: "open").pluck(:id),
      ).to contain_exactly(topic.id)
    end

    it "should only return topics that have been deleted when status is `deleted` and user can see deleted topics" do
      expect(
        TopicsFilter.new(guardian: Guardian.new(admin)).filter_status(status: "deleted").pluck(:id),
      ).to contain_exactly(deleted_topic_id)
    end

    it "should status filter when status is `deleted` and user cannot see deleted topics" do
      expect(
        TopicsFilter.new(guardian: Guardian.new).filter_status(status: "deleted").pluck(:id),
      ).to contain_exactly(topic.id, closed_topic.id, archived_topic.id)
    end

    it "should only return topics that have been archived when status is `archived`" do
      expect(
        TopicsFilter.new(guardian: Guardian.new).filter_status(status: "archived").pluck(:id),
      ).to contain_exactly(archived_topic.id)
    end

    it "should only return topics that are visible when status is `listed`" do
      Topic.update_all(visible: false)
      topic.update!(visible: true)

      expect(
        TopicsFilter.new(guardian: Guardian.new).filter_status(status: "listed").pluck(:id),
      ).to contain_exactly(topic.id)
    end

    it "should only return topics that are not visible when status is `unlisted`" do
      Topic.update_all(visible: true)
      topic.update!(visible: false)

      expect(
        TopicsFilter.new(guardian: Guardian.new).filter_status(status: "unlisted").pluck(:id),
      ).to contain_exactly(topic.id)
    end
  end

  describe "#filter_tags" do
    fab!(:tag) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }

    fab!(:group_only_tag) { Fabricate(:tag) }
    fab!(:group) { Fabricate(:group) }

    let!(:staff_tag_group) do
      Fabricate(
        :tag_group,
        permissions: {
          group.name => TagGroupPermission.permission_types[:full],
        },
        tag_names: [group_only_tag.name],
      )
    end

    fab!(:topic_without_tag) { Fabricate(:topic) }
    fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
    fab!(:topic_with_tag_and_tag2) { Fabricate(:topic, tags: [tag, tag2]) }
    fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
    fab!(:topic_with_group_only_tag) { Fabricate(:topic, tags: [group_only_tag]) }

    it "should not filter any topics by tags when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: [tag.name, tag2.name], match_all: true, exclude: false)
          .pluck(:id),
      ).to contain_exactly(
        topic_without_tag.id,
        topic_with_tag.id,
        topic_with_tag_and_tag2.id,
        topic_with_tag2.id,
        topic_with_group_only_tag.id,
      )
    end

    it "should only return topics that are tagged with all of the specified tags when `match_all` is `true`" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: [tag.name, tag2.name], match_all: true, exclude: false)
          .pluck(:id),
      ).to contain_exactly(topic_with_tag_and_tag2.id)
    end

    it "should only return topics that are tagged with any of the specified tags when `match_all` is `false`" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: [tag2.name], match_all: false, exclude: false)
          .pluck(:id),
      ).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag2.id)
    end

    it "should not return any topics when `match_all` is `true` and one of specified tags is invalid" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: ["invalid", tag.name, tag2.name], match_all: true, exclude: false)
          .pluck(:id),
      ).to eq([])
    end

    it "should still filter topics by specificed tags when `match_all` is `false` even if one of the tags is invalid" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(
            tag_names: ["invalid", tag.name, tag2.name],
            match_all: false,
            exclude: false,
          )
          .pluck(:id),
      ).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag.id, topic_with_tag2.id)
    end

    it "should not return any topics when user tries to filter topics by tags that are hidden" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: [group_only_tag.name], match_all: true, exclude: false)
          .pluck(:id),
      ).to eq([])
    end

    it "should allow user with permission to filter topics by tags that are hidden" do
      group.add(admin)

      expect(
        TopicsFilter
          .new(guardian: Guardian.new(admin))
          .filter_tags(tag_names: [group_only_tag.name])
          .pluck(:id),
      ).to contain_exactly(topic_with_group_only_tag.id)
    end

    it "should only return topics that are not tagged with all of the specified tags when `match_all` is `true` and `exclude` is `true`" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: [tag.name], match_all: true, exclude: true)
          .pluck(:id),
      ).to contain_exactly(topic_without_tag.id, topic_with_tag2.id, topic_with_group_only_tag.id)

      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: [tag.name, tag2.name], match_all: true, exclude: true)
          .pluck(:id),
      ).to contain_exactly(
        topic_without_tag.id,
        topic_with_tag.id,
        topic_with_tag2.id,
        topic_with_group_only_tag.id,
      )
    end

    it "should only return topics that are not tagged with any of the specified tags when `match_all` is `false` and `exclude` is `true`" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: [tag.name], match_all: false, exclude: true)
          .pluck(:id),
      ).to contain_exactly(topic_without_tag.id, topic_with_group_only_tag.id, topic_with_tag2.id)

      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_tags(tag_names: [tag.name, tag2.name], match_all: false, exclude: true)
          .pluck(:id),
      ).to contain_exactly(topic_without_tag.id, topic_with_group_only_tag.id)
    end
  end
end

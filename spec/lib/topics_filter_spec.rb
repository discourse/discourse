# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:admin) { Fabricate(:admin) }

  describe "#filter_from_query_string" do
    describe "when filtering with multiple filters" do
      fab!(:tag) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
      fab!(:closed_topic_with_tag) { Fabricate(:topic, tags: [tag], closed: true) }
      fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
      fab!(:closed_topic_with_tag2) { Fabricate(:topic, tags: [tag2], closed: true) }

      it "should return the right topics when query string is `status:closed tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:closed tags:tag1,tag2")
            .pluck(:id),
        ).to contain_exactly(closed_topic_with_tag.id, closed_topic_with_tag2.id)
      end
    end

    describe "when filtering by status" do
      fab!(:topic) { Fabricate(:topic) }
      fab!(:closed_topic) { Fabricate(:topic, closed: true) }
      fab!(:archived_topic) { Fabricate(:topic, archived: true) }
      fab!(:deleted_topic_id) { Fabricate(:topic, deleted_at: Time.zone.now).id }

      it "should only return topics that have not been closed or archived when query string is `status:open`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:open")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that have been deleted when query string is `status:deleted` and user can see deleted topics" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new(admin))
            .filter_from_query_string("status:deleted")
            .pluck(:id),
        ).to contain_exactly(deleted_topic_id)
      end

      it "should ignore status filter when query string is `status:deleted` and user cannot see deleted topics" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:deleted")
            .pluck(:id),
        ).to contain_exactly(topic.id, closed_topic.id, archived_topic.id)
      end

      it "should only return topics that have been archived when query string is `status:archived`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:archived")
            .pluck(:id),
        ).to contain_exactly(archived_topic.id)
      end

      it "should only return topics that are visible when query string is `status:listed`" do
        Topic.update_all(visible: false)
        topic.update!(visible: true)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:listed")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that are not visible when query string is `status:unlisted`" do
        Topic.update_all(visible: true)
        topic.update!(visible: false)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:unlisted")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end
    end

    describe "when filtering by tags" do
      fab!(:tag) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }
      fab!(:tag3) { Fabricate(:tag, name: "tag3") }

      fab!(:group_only_tag) { Fabricate(:tag, name: "group-only-tag") }
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
            .filter_from_query_string("tags:#{tag.name}+#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag.id,
          topic_with_tag_and_tag2.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      it "should only return topics that are tagged with all of the specified tags when query string is `tags:tag1+tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name}+#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id)
      end

      it "should only return topics that are tagged with tag1 and tag2 when query string is `tags:tag1 tags:tag2`" do
        topic_with_tag_and_tag2_and_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name} tags:#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag_and_tag2_and_tag3.id)
      end

      it "should only return topics that are tagged with tag1 and tag2 but not tag3 when query string is `tags:tag1 tags:tag2 -tags:tag3`" do
        topic_with_tag_and_tag2_and_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name} tags:#{tag2.name} -tags:tag3")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id)
      end

      it "should only return topics that are tagged with any of the specified tags when query string is `tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name},#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id, topic_with_tag_and_tag2.id, topic_with_tag2.id)
      end

      it "should not return any topics when query string is `tags:tag1+tag2+invalid`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:tag1+tag2+invalid")
            .pluck(:id),
        ).to eq([])
      end

      it "should still filter topics by specificed tags when query string is `tags:tag1,tag2,invalid`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:tag1,tag2,invalid")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag.id, topic_with_tag2.id)
      end

      it "should not return any topics when query string is `tags:group-only-tag` because specified tag is hidden to user" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:group-only-tag")
            .pluck(:id),
        ).to eq([])
      end

      it "should return the right topics when query string is `tags:group-only-tag` and user has access to specified tag" do
        group.add(admin)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new(admin))
            .filter_from_query_string("tags:group-only-tag")
            .pluck(:id),
        ).to contain_exactly(topic_with_group_only_tag.id)
      end

      it "should only return topics that are not tagged with specified tag when query string is `-tags:tag1`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1")
            .pluck(:id),
        ).to contain_exactly(topic_without_tag.id, topic_with_tag2.id, topic_with_group_only_tag.id)
      end

      it "should only return topics that are not tagged with all of the specified tags when query string is `-tags:tag1+tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1+tag2")
            .pluck(:id),
        ).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      it "should only return topics that are not tagged with any of the specified tags when query string is `-tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1,tag2")
            .pluck(:id),
        ).to contain_exactly(topic_without_tag.id, topic_with_group_only_tag.id)
      end
    end
  end
end

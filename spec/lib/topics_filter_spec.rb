# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:closed_topic) { Fabricate(:topic, closed: true) }
  fab!(:archived_topic) { Fabricate(:topic, archived: true) }
  fab!(:deleted_topic_id) { Fabricate(:topic, deleted_at: Time.zone.now).id }

  describe "#filter" do
    it "should return all topics when input is blank" do
      expect(TopicsFilter.new(guardian: Guardian.new).filter.pluck(:id)).to contain_exactly(
        topic.id,
        closed_topic.id,
        archived_topic.id,
      )
    end

    context "when filtering by topic's status" do
      it "should only return topics that have not been closed or archived when status is `open`" do
        expect(
          TopicsFilter.new(guardian: Guardian.new).filter(status: "open").pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that have been deleted when status is `deleted` and user can see deleted topics" do
        expect(
          TopicsFilter.new(guardian: Guardian.new(admin)).filter(status: "deleted").pluck(:id),
        ).to contain_exactly(deleted_topic_id)
      end

      it "should status filter when status is `deleted` and user cannot see deleted topics" do
        expect(
          TopicsFilter.new(guardian: Guardian.new).filter(status: "deleted").pluck(:id),
        ).to contain_exactly(topic.id, closed_topic.id, archived_topic.id)
      end

      it "should only return topics that have been archived when status is `archived`" do
        expect(
          TopicsFilter.new(guardian: Guardian.new).filter(status: "archived").pluck(:id),
        ).to contain_exactly(archived_topic.id)
      end

      it "should only return topics that are visible when status is `listed`" do
        Topic.update_all(visible: false)
        topic.update!(visible: true)

        expect(
          TopicsFilter.new(guardian: Guardian.new).filter(status: "listed").pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that are not visible when status is `unlisted`" do
        Topic.update_all(visible: true)
        topic.update!(visible: false)

        expect(
          TopicsFilter.new(guardian: Guardian.new).filter(status: "unlisted").pluck(:id),
        ).to contain_exactly(topic.id)
      end
    end
  end
end

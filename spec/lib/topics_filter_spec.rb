# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:closed_topic) { Fabricate(:topic, closed: true) }
  fab!(:archived_topic) { Fabricate(:topic, archived: true) }
  fab!(:deleted_topic_id) { Fabricate(:topic, deleted_at: Time.zone.now).id }

  describe "#filter" do
    it "should return all topics when input is blank" do
      expect(TopicsFilter.new(guardian: Guardian.new).filter("").pluck(:id)).to contain_exactly(
        topic.id,
        closed_topic.id,
        archived_topic.id,
      )
    end

    it "should return all topics when input does not match any filters" do
      expect(
        TopicsFilter.new(guardian: Guardian.new).filter("randomstring").pluck(:id),
      ).to contain_exactly(topic.id, closed_topic.id, archived_topic.id)
    end

    it "should only return topics that have not been closed or archived when input is `status:open`" do
      expect(
        TopicsFilter.new(guardian: Guardian.new).filter("status:open").pluck(:id),
      ).to contain_exactly(topic.id)
    end

    it "should only return topics that have been deleted when input is `status:deleted` and user can see deleted topics" do
      expect(
        TopicsFilter.new(guardian: Guardian.new(admin)).filter("status:deleted").pluck(:id),
      ).to contain_exactly(deleted_topic_id)
    end

    it "should status filter when input is `status:deleted` and user cannot see deleted topics" do
      expect(
        TopicsFilter.new(guardian: Guardian.new).filter("status:deleted").pluck(:id),
      ).to contain_exactly(topic.id, closed_topic.id, archived_topic.id)
    end

    it "should only return topics that have been archived when input is `status:archived`" do
      expect(
        TopicsFilter.new(guardian: Guardian.new).filter("status:archived").pluck(:id),
      ).to contain_exactly(archived_topic.id)
    end
  end
end

# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Jobs::CleanUpTags, "#execute" do
  include_context "with unit five content guards"

  fab!(:tag) { Fabricate(:tag, id: 113_572_001, created_at: 1.hour.ago) }
  fab!(:other_tag) { Fabricate(:tag, id: 113_572_002, created_at: 1.hour.ago) }

  before { SiteSetting.automatically_clean_unused_tags = true }

  %i[allow deny].each do |side|
    it "[cr-u5] keeps a topicless #{side}-referenced tag while the scheduled job deletes an unused peer" do
      expect(tag.topics).to be_empty
      protect_targets(side, tag_ids: [tag.id])
      tag_ids = [tag.id, other_tag.id]
      protected_id = tag.id

      described_class.new.execute({})

      expect(Tag.where(id: tag_ids).pluck(:id)).to eq([protected_id]),
      "CLEANUP JOB: referenced tag was deleted or unreferenced cleanup was blocked"
    end
  end

  it "[cr-u5] deletes both old unused tags through the scheduled job with no rules" do
    expect(McpContentRule.count).to eq(0)
    tag_ids = [tag.id, other_tag.id]

    described_class.new.execute({})

    expect(Tag.where(id: tag_ids)).to be_empty
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions

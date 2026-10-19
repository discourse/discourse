# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ReviewableAgent do
  fab!(:agent, :ai_agent)
  fab!(:reviewable, :reviewable_flagged_post)

  it "keeps attribution after its agent is deleted" do
    described_class.create!(reviewable_id: reviewable.id, ai_agent_id: agent.id)

    agent.destroy!

    expect(described_class.where(reviewable_id: reviewable.id).pluck(:ai_agent_id)).to eq(
      [agent.id],
    )
  end

  it "deletes attribution when its reviewable is destroyed" do
    other_reviewable = Fabricate(:reviewable_flagged_post)
    described_class.create!(reviewable_id: reviewable.id, ai_agent_id: agent.id)
    described_class.create!(reviewable_id: other_reviewable.id, ai_agent_id: agent.id)

    reviewable.destroy!

    expect(described_class.pluck(:reviewable_id)).to eq([other_reviewable.id])
  end

  it "deletes attribution when its reviewable is bulk-deleted" do
    other_reviewable = Fabricate(:reviewable_flagged_post)
    described_class.create!(reviewable_id: reviewable.id, ai_agent_id: agent.id)
    described_class.create!(reviewable_id: other_reviewable.id, ai_agent_id: agent.id)

    Reviewable.where(id: reviewable.id).delete_all

    expect(described_class.pluck(:reviewable_id)).to eq([other_reviewable.id])
  end
end

# frozen_string_literal: true

RSpec.describe Jobs::CleanUpAiArtifacts do
  fab!(:user)
  fab!(:post)

  before { enable_current_plugin }

  it "removes only orphaned artifacts older than 24 hours" do
    old_orphan = Fabricate(:ai_artifact, user: user, post: nil, created_at: 25.hours.ago)
    fresh_orphan = Fabricate(:ai_artifact, user: user, post: nil)
    old_linked = Fabricate(:ai_artifact, user: user, post: post, created_at: 30.days.ago)

    described_class.new.execute({})

    expect(AiArtifact.exists?(old_orphan.id)).to be(false)
    expect(AiArtifact.exists?(fresh_orphan.id)).to be(true)
    expect(AiArtifact.exists?(old_linked.id)).to be(true)
  end
end

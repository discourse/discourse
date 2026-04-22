# frozen_string_literal: true

RSpec.describe Jobs::CleanUpWebArtifacts do
  fab!(:user)

  it "removes orphan artifacts older than 24 hours" do
    old_orphan = Fabricate(:web_artifact, user: user, post: nil, created_at: 25.hours.ago)
    recent_orphan = Fabricate(:web_artifact, user: user, post: nil, created_at: 1.hour.ago)
    linked = Fabricate(:web_artifact, user: user, created_at: 25.hours.ago)

    described_class.new.execute({})

    expect(WebArtifact.exists?(old_orphan.id)).to eq(false)
    expect(WebArtifact.exists?(recent_orphan.id)).to eq(true)
    expect(WebArtifact.exists?(linked.id)).to eq(true)
  end
end

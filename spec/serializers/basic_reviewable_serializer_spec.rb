# frozen_string_literal: true

describe BasicReviewableSerializer do
  fab!(:reviewable) { Fabricate(:reviewable) }

  def get_json
    described_class.new(reviewable, root: false).as_json
  end

  it "includes reviewable id" do
    expect(get_json[:id]).to eq(reviewable.id)
  end

  it "includes reviewable type" do
    reviewable.update!(type: "ReviewableFlaggedPost")
    expect(get_json[:type]).to eq("ReviewableFlaggedPost")
  end

  it "includes a boolean that indicates whether the reviewable pending is pending or not" do
    reviewable.update!(status: Reviewable.statuses[:approved])
    expect(get_json[:pending]).to eq(false)
    reviewable.update!(status: Reviewable.statuses[:pending])
    expect(get_json[:pending]).to eq(true)
  end

  it "includes reviewable flagger_username" do
    reviewable.update!(
      created_by: Fabricate(:user, username: "gg.osama")
    )
    expect(get_json[:flagger_username]).to eq("gg.osama")
  end
end

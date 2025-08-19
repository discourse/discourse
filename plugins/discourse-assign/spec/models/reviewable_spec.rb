# frozen_string_literal: true

describe Reviewable do
  fab!(:user)
  fab!(:admin)
  fab!(:post1) { Fabricate(:post) }
  fab!(:post2) { Fabricate(:post) }
  fab!(:reviewable1) { Fabricate(:reviewable_flagged_post, target: post1) }
  fab!(:reviewable2) { Fabricate(:reviewable_flagged_post, target: post2) }

  before { SiteSetting.assign_enabled = true }

  it "can filter by assigned_to" do
    Assignment.create!(
      target: post1,
      topic_id: post1.topic.id,
      assigned_by_user: user,
      assigned_to: user,
    )
    Assignment.create!(
      target: post2,
      topic_id: post2.topic.id,
      assigned_by_user: user,
      assigned_to: admin,
    )

    expect(Reviewable.list_for(admin, additional_filters: { assigned_to: user.username })).to eq(
      [reviewable1],
    )
  end
end

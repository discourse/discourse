# frozen_string_literal: true

RSpec.describe ReviewableHistory, type: :model do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)

  it "adds a `created` history event when a reviewable is created" do
    reviewable = ReviewableUser.needs_review!(target: user, created_by: admin)
    reviewable.perform(moderator, :approve_user)
    reviewable = ReviewableUser.needs_review!(target: user, created_by: admin)

    history = reviewable.history
    expect(history.size).to eq(3)

    expect(history[0]).to be_created
    expect(history[0]).to be_pending
    expect(history[0].created_by).to eq(admin)
  end

  it "adds a `transitioned` event when transitioning" do
    reviewable = ReviewableUser.needs_review!(target: user, created_by: admin)
    reviewable.perform(moderator, :approve_user)
    reviewable = ReviewableUser.needs_review!(target: user, created_by: admin)

    history = reviewable.history
    expect(history.size).to eq(3)
    expect(history[1]).to be_transitioned
    expect(history[1]).to be_approved
    expect(history[1].created_by).to eq(moderator)

    expect(history[2]).to be_transitioned
    expect(history[2]).to be_pending
    expect(history[2].created_by).to eq(admin)
  end

  it "won't log a transition to the same state" do
    p0 = Fabricate(:post)
    reviewable = PostActionCreator.spam(Fabricate(:user, refresh_auto_groups: true), p0).reviewable
    expect(reviewable.reviewable_histories.size).to eq(1)
    PostActionCreator.inappropriate(Fabricate(:user), p0)
    expect(reviewable.reload.reviewable_histories.size).to eq(1)
  end

  it "adds an `edited` event when edited" do
    reviewable = Fabricate(:reviewable)
    old_category = reviewable.category

    reviewable.update_fields({ category_id: nil }, moderator)

    history = reviewable.history
    expect(history.size).to eq(2)

    expect(history[1]).to be_edited
    expect(history[1].created_by).to eq(moderator)
    expect(history[1].edited).to eq("category_id" => [old_category.id, nil])
  end
end

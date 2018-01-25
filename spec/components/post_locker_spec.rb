require 'rails_helper'
require_dependency 'post_locker'

describe PostLocker do
  let(:moderator) { Fabricate(:moderator) }
  let(:post) { Fabricate(:post) }

  it "doesn't allow regular users to lock posts" do
    expect {
      PostLocker.new(post, post.user).lock
    }.to raise_error(Discourse::InvalidAccess)

    expect(post).not_to be_locked
    expect(post.locked_by_id).to be_blank
  end

  it "doesn't allow regular users to unlock posts" do
    PostLocker.new(post, moderator).lock

    expect {
      PostLocker.new(post, post.user).lock
    }.to raise_error(Discourse::InvalidAccess)

    expect(post).to be_locked
    expect(post.locked_by_id).to eq(moderator.id)
  end

  it "allows staff to lock and unlock posts" do
    expect(post).not_to be_locked
    expect(post.locked_by_id).to be_blank

    PostLocker.new(post, moderator).lock
    expect(post).to be_locked
    expect(post.locked_by_id).to eq(moderator.id)
    expect(UserHistory.where(
      acting_user_id: moderator.id,
      action: UserHistory.actions[:post_locked]
    ).exists?).to eq(true)

    PostLocker.new(post, moderator).unlock
    expect(post).not_to be_locked
    expect(post.locked_by_id).to be_blank
    expect(UserHistory.where(
      acting_user_id: moderator.id,
      action: UserHistory.actions[:post_unlocked]
    ).exists?).to eq(true)
  end

end

# frozen_string_literal: true

require 'rails_helper'

describe Jobs::TruncateUserFlagStats do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  before do
    # We might make this a site setting eventually
    Jobs::TruncateUserFlagStats.stubs(:truncate_to).returns(2)
  end

  def perform(*users)
    described_class.new.execute(user_ids: users.map(&:id))
    users.each { |u| u.reload }
  end

  it "raises an error without user ids" do
    expect {
      described_class.new.execute({})
    }.to raise_error(Discourse::InvalidParameters)
  end

  it "does nothing if the user doesn't have enough flags" do
    user.user_stat.update_columns(flags_agreed: 1)
    perform(user)

    expect(user.user_stat.flags_agreed).to eq(1)
    expect(user.user_stat.flags_disagreed).to eq(0)
    expect(user.user_stat.flags_ignored).to eq(0)
  end

  it "removes the statuses of old flags (integration test)" do
    p0 = Fabricate(:post)
    p1 = Fabricate(:post)
    p2 = Fabricate(:post, user: user)
    p3 = Fabricate(:post)

    freeze_time 10.minutes.ago
    r0 = PostActionCreator.spam(user, p0).reviewable
    freeze_time 1.minute.from_now
    r1 = PostActionCreator.spam(user, p1).reviewable
    freeze_time 1.minute.from_now
    r2 = PostActionCreator.spam(user, p2).reviewable
    freeze_time 1.minute.from_now
    r3 = PostActionCreator.spam(user, p3).reviewable

    freeze_time 1.minute.from_now
    PostActionCreator.spam(other_user, p3).reviewable
    freeze_time 1.minute.from_now
    PostActionCreator.spam(other_user, p2).reviewable
    freeze_time 1.minute.from_now
    PostActionCreator.spam(other_user, p1).reviewable

    unfreeze_time

    r0.perform(Discourse.system_user, :agree_and_keep)
    r1.perform(Discourse.system_user, :disagree)
    r2.perform(Discourse.system_user, :ignore)
    r3.perform(Discourse.system_user, :agree_and_keep)

    user.user_stat.reload
    other_user.user_stat.reload

    expect(user.user_stat.flags_agreed).to eq(2)
    expect(user.user_stat.flags_disagreed).to eq(1)
    expect(user.user_stat.flags_ignored).to eq(0)

    expect(other_user.user_stat.flags_agreed).to eq(1)
    expect(other_user.user_stat.flags_disagreed).to eq(1)
    expect(other_user.user_stat.flags_ignored).to eq(1)

    perform(user, other_user)

    expect(user.user_stat.flags_agreed).to eq(1)
    expect(user.user_stat.flags_disagreed).to eq(1)
    expect(user.user_stat.flags_ignored).to eq(0)

    expect(other_user.user_stat.flags_agreed).to eq(0)
    expect(other_user.user_stat.flags_disagreed).to eq(1)
    expect(other_user.user_stat.flags_ignored).to eq(1)
  end

end

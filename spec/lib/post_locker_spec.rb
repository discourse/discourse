# frozen_string_literal: true

RSpec.describe PostLocker do
  fab!(:moderator)
  fab!(:post)

  it "doesn't allow regular users to lock posts" do
    expect { PostLocker.new(post, post.user).lock }.to raise_error(Discourse::InvalidAccess)

    expect(post).not_to be_locked
    expect(post.locked_by_id).to be_blank
  end

  it "doesn't allow regular users to unlock posts" do
    PostLocker.new(post, moderator).lock

    expect { PostLocker.new(post, post.user).lock }.to raise_error(Discourse::InvalidAccess)

    expect(post).to be_locked
    expect(post.locked_by_id).to eq(moderator.id)
  end

  it "allows staff to lock and unlock posts" do
    expect(post).not_to be_locked
    expect(post.locked_by_id).to be_blank

    PostLocker.new(post, moderator).lock
    expect(post).to be_locked
    expect(post.locked_by_id).to eq(moderator.id)
    expect(
      UserHistory.where(
        acting_user_id: moderator.id,
        action: UserHistory.actions[:post_locked],
      ).exists?,
    ).to eq(true)

    PostLocker.new(post, moderator).unlock
    expect(post).not_to be_locked
    expect(post.locked_by_id).to be_blank
    expect(
      UserHistory.where(
        acting_user_id: moderator.id,
        action: UserHistory.actions[:post_unlocked],
      ).exists?,
    ).to eq(true)
  end

  describe "events" do
    def lock_events(&)
      DiscourseEvent
        .track_events(&)
        .filter_map do |event|
          if %i[post_locked post_unlocked].include?(event[:event_name])
            [event[:event_name], event[:params]]
          end
        end
    end

    it "fires post_locked as the staff member who locked the post" do
      expect(lock_events { PostLocker.new(post, moderator).lock }).to eq(
        [[:post_locked, [post, { acting_user: moderator }]]],
      )
    end

    it "fires post_unlocked as the staff member who unlocked the post" do
      PostLocker.new(post, moderator).lock
      admin = Fabricate(:admin)

      expect(lock_events { PostLocker.new(post, admin).unlock }).to eq(
        [[:post_unlocked, [post, { acting_user: admin }]]],
      )
    end

    it "fires nothing when locking a locked post, but still records who locked it last",
       :aggregate_failures do
      PostLocker.new(post, moderator).lock
      admin = Fabricate(:admin)

      expect(lock_events { PostLocker.new(post, admin).lock }).to be_empty
      expect(post.reload.locked_by_id).to eq(admin.id)
      expect(
        UserHistory.where(acting_user_id: admin.id, action: UserHistory.actions[:post_locked]),
      ).to exist
    end

    it "fires nothing when unlocking a post that isn't locked" do
      expect(lock_events { PostLocker.new(post, moderator).unlock }).to be_empty
    end

    it "fires nothing when a regular user tries to lock the post" do
      events =
        lock_events do
          expect { PostLocker.new(post, post.user).lock }.to raise_error(Discourse::InvalidAccess)
        end

      expect(events).to be_empty
    end

    it "fires nothing when an enclosing transaction rolls back" do
      events =
        lock_events do
          ActiveRecord::Base.transaction do
            PostLocker.new(post, moderator).lock
            raise ActiveRecord::Rollback
          end
        end

      expect(events).to be_empty
      expect(post.reload).not_to be_locked
    end
  end
end

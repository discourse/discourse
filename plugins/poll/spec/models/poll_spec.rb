# frozen_string_literal: true

RSpec.describe DiscoursePoll::Poll do
  describe "#reload" do
    it "accepts options like ActiveRecord's reload" do
      poll = Fabricate(:poll)
      expect { poll.reload(lock: true) }.not_to raise_error
    end
  end

  describe ".transform_for_user_field_override" do
    it "Transforms UserField name if a matching CustomUserField is present" do
      user_field_name = "Something Cool"
      user_field = Fabricate(:user_field, name: user_field_name)
      expect(DiscoursePoll::Poll.transform_for_user_field_override(user_field_name)).to eq(
        "user_field_#{user_field.id}",
      )
    end

    it "does not transform UserField name if a matching CustomUserField is not present" do
      user_field_name = "Something Cool"
      user_field = Fabricate(:user_field, name: "Something Else!")
      expect(DiscoursePoll::Poll.transform_for_user_field_override(user_field_name)).to eq(
        user_field_name,
      )
    end
  end

  describe "can see results?" do
    it "everyone can see results when results setting is always" do
      post = Fabricate(:post, raw: "[poll]\n- A\n- B\n[/poll]")
      user = Fabricate(:user)
      expect(post.polls.first.can_see_results?(user)).to eq(true)
    end

    it "users who voted can see results when results setting is on_vote" do
      post = Fabricate(:post, raw: "[poll results=on_vote]\n- A\n- B\n[/poll]")
      user = Fabricate(:user)
      poll = post.polls.first
      option = poll.poll_options.first

      expect(poll.can_see_results?(user)).to eq(false)
      poll.poll_votes.create!(poll_option_id: option.id, user_id: user.id)
      expect(poll.reload.can_see_results?(user)).to eq(true)
    end

    it "author can see results when results setting is on_vote" do
      author = Fabricate(:user, refresh_auto_groups: true)
      post = Fabricate(:post, user: author, raw: "[poll results=on_vote]\n- A\n- B\n[/poll]")
      poll = post.polls.first
      option = poll.poll_options.first

      expect(poll.can_see_results?(author)).to eq(true)
      poll.poll_votes.create!(poll_option_id: option.id, user_id: author.id)
      expect(poll.can_see_results?(author)).to eq(true)
    end

    it "everyone can see results when results setting is on_vote and poll is closed" do
      post = Fabricate(:post, raw: "[poll results=on_vote]\n- A\n- B\n[/poll]")
      user = Fabricate(:user)
      poll = post.polls.first

      expect(poll.can_see_results?(user)).to eq(false)
      poll.update(close_at: Date.yesterday)
      expect(poll.can_see_results?(user)).to eq(true)
    end

    it "only staff members can see results when results setting is staff_only" do
      post = Fabricate(:post, raw: "[poll results=staff_only]\n- A\n- B\n[/poll]")
      user = Fabricate(:user, refresh_auto_groups: true)
      poll = post.polls.first
      option = poll.poll_options.first

      expect(poll.can_see_results?(user)).to eq(false)
      poll.poll_votes.create!(poll_option_id: option.id, user_id: user.id)
      expect(poll.can_see_results?(user)).to eq(false)
      user.update!(moderator: true)
      expect(poll.can_see_results?(user)).to eq(true)
    end
  end

  describe "when post is trashed" do
    it "maintains the association" do
      user = Fabricate(:user, refresh_auto_groups: true)
      post = Fabricate(:post, raw: "[poll results=staff_only]\n- A\n- B\n[/poll]", user: user)
      poll = post.polls.first

      post.trash!
      poll.reload

      expect(poll.post).to eq(post)
    end
  end

  it "is not throwing an error when double save" do
    post = Fabricate(:post, raw: "[poll]\n- A\n- B\n[/poll]")
    expect { post.save! }.not_to raise_error
  end

  describe ".schedule_imminent_closures" do
    # `update_columns` bypasses the after_commit scheduling.
    fab!(:poll)

    before { freeze_time(Time.zone.now.beginning_of_minute) }

    def close_job_args(poll)
      { poll_id: poll.id, close_at: poll.close_at.to_i }
    end

    it "schedules a poll that closes within the window for its close time" do
      poll.update_columns(close_at: 20.minutes.from_now)

      Poll.schedule_imminent_closures

      expect_job_enqueued(job: :close_poll, args: close_job_args(poll), at: poll.close_at)
    end

    it "schedules an overdue poll to close right away" do
      poll.update_columns(close_at: 1.hour.ago)

      Poll.schedule_imminent_closures

      expect_job_enqueued(job: :close_poll, args: close_job_args(poll), at: Time.zone.now)
    end

    it "schedules each poll once" do
      poll.update_columns(close_at: 20.minutes.from_now)

      expect { 2.times { Poll.schedule_imminent_closures } }.to change {
        Jobs::ClosePoll.jobs.size
      }.by(1)
    end

    it "skips polls that close later, are closed, or have no close time" do
      poll.update_columns(close_at: 1.hour.from_now)
      Fabricate(:poll, close_at: 1.minute.from_now, status: :closed)
      Fabricate(:poll, close_at: nil)

      expect { Poll.schedule_imminent_closures }.not_to change { Jobs::ClosePoll.jobs.size }
    end

    it "skips polls on deleted posts and in archived topics" do
      poll.update_columns(close_at: 1.minute.from_now)
      poll.post.trash!
      archived_poll = Fabricate(:poll)
      archived_poll.update_columns(close_at: 1.minute.from_now)
      archived_poll.post.topic.update!(archived: true)

      expect { Poll.schedule_imminent_closures }.not_to change { Jobs::ClosePoll.jobs.size }
    end
  end

  describe "saving a poll" do
    before { freeze_time(Time.zone.now.beginning_of_minute) }

    it "schedules the closure of a poll that closes soon" do
      poll = Fabricate(:poll, close_at: 5.minutes.from_now)

      expect_job_enqueued(
        job: :close_poll,
        args: {
          poll_id: poll.id,
          close_at: poll.close_at.to_i,
        },
        at: poll.close_at,
      )
    end

    it "schedules the closure again when the close time changes" do
      poll = Fabricate(:poll, close_at: 5.minutes.from_now)

      poll.update!(close_at: 10.minutes.from_now)

      expect_job_enqueued(
        job: :close_poll,
        args: {
          poll_id: poll.id,
          close_at: poll.close_at.to_i,
        },
        at: poll.close_at,
      )
    end

    it "schedules the closure of a reopened poll that closes soon" do
      poll = Fabricate(:poll, close_at: 5.minutes.from_now, status: :closed)

      poll.update!(status: :open)

      expect_job_enqueued(
        job: :close_poll,
        args: {
          poll_id: poll.id,
          close_at: poll.close_at.to_i,
        },
        at: poll.close_at,
      )
    end
  end
end

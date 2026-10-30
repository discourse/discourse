# frozen_string_literal: true

RSpec.describe "Poll closure scheduling" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  it "schedules the closure of a poll that an edit adds" do
    freeze_time(Time.zone.now.beginning_of_minute)
    post = Fabricate(:post, user:, raw: "This post has no poll yet")
    close_at = 10.minutes.from_now

    PostRevisor.new(post).revise!(user, raw: "[poll close=#{close_at.iso8601}]\n- A\n- B\n[/poll]")

    expect_job_enqueued(
      job: :close_poll,
      args: {
        poll_id: post.polls.first.id,
        close_at: close_at.to_i,
      },
      at: close_at,
    )
  end
end

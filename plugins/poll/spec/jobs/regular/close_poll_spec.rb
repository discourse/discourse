# frozen_string_literal: true

RSpec.describe Jobs::ClosePoll do
  let(:post) { Fabricate(:post, raw: "[poll]\n- A\n- B\n[/poll]") }
  let(:poll) { post.polls.first }

  before { poll.update!(close_at: 1.minute.ago) }

  it "automatically closes a poll" do
    expect(poll.closed?).to eq(false)

    Jobs::ClosePoll.new.execute(poll_id: poll.id, close_at: poll.close_at.to_i)

    poll.reload
    expect(poll.closed?).to eq(true)
    expect(poll.closed_by_id).to eq(Discourse.system_user.id)
  end

  it "logs the automatic close as the system user" do
    Jobs::ClosePoll.new.execute(poll_id: poll.id, close_at: poll.close_at.to_i)

    log = UserHistory.last
    expect(log.custom_type).to eq("poll_closed")
    expect(log.acting_user_id).to eq(Discourse.system_user.id)
  end

  it "closes a poll that moved to another post after it was scheduled" do
    poll.update_columns(post_id: Fabricate(:post, topic: post.topic).id)

    Jobs::ClosePoll.new.execute(poll_id: poll.id, close_at: poll.close_at.to_i)

    expect(poll.reload.closed?).to eq(true)
  end

  it "leaves the poll open when the job's close time differs from the poll's" do
    Jobs::ClosePoll.new.execute(poll_id: poll.id, close_at: 1.hour.ago.to_i)
    Jobs::ClosePoll.new.execute(post_id: post.id, poll_name: poll.name)

    expect(poll.reload.closed?).to eq(false)
  end
end

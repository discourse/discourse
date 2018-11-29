require "rails_helper"

describe Jobs::ClosePoll do

  it "automatically closes a poll" do
    post = Fabricate(:post, raw: "[poll]\n- A\n- B\n[/poll]")

    expect(post.polls.first.closed?).to eq(false)

    Jobs::ClosePoll.new.execute(post_id: post.id, poll_name: "poll")

    expect(post.polls.first.closed?).to eq(true)
  end

end

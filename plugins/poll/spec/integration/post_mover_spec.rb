# frozen_string_literal: true

RSpec.describe "Poll post_moved handler" do
  fab!(:admin)
  fab!(:user1, :user)
  fab!(:user2, :user)

  fab!(:first_post) do
    Fabricate(
      :post,
      user: admin,
      raw: "[poll name=first_post_poll type=regular]\n- Option A\n- Option B\n[/poll]",
    )
  end

  fab!(:source_topic) { first_post.topic }

  fab!(:reply) do
    Fabricate(
      :post,
      topic: source_topic,
      user: admin,
      raw: "[poll name=reply_poll type=regular]\n- Option A\n- Option B\n[/poll]",
    )
  end

  fab!(:first_post_poll) { first_post.polls.find_by(name: "first_post_poll") }
  fab!(:reply_poll) { reply.polls.find_by(name: "reply_poll") }

  fab!(:user1_first_post_poll_votes) do
    first_post_poll.poll_options.map do |option|
      Fabricate(:poll_vote, poll: first_post_poll, poll_option: option, user: user1)
    end
  end

  fab!(:user2_reply_poll_votes) do
    reply_poll.poll_options.map do |option|
      Fabricate(:poll_vote, poll: reply_poll, poll_option: option, user: user2)
    end
  end

  fab!(:destination_topic) { Fabricate(:post, user: admin).topic }

  before { Jobs.run_immediately! }

  it "moves polls, options, and votes when the first post is moved" do
    original_options = first_post_poll.poll_options.to_a

    source_topic.move_posts(admin, [first_post.id], destination_topic_id: destination_topic.id)

    new_post = destination_topic.posts.last
    moved_poll = new_post.polls.find_by(name: "first_post_poll")

    expect(moved_poll).to eq(first_post_poll)
    expect(moved_poll.poll_options).to contain_exactly(*original_options)
    expect(moved_poll.poll_votes.map { |vote| [vote.user, vote.poll_option] }).to contain_exactly(
      *original_options.map { |option| [user1, option] },
    )

    expect(new_post.custom_fields[DiscoursePoll::HAS_POLLS]).to eq(true)
    expect(Poll.exists?(post_id: first_post.id)).to eq(false)
  end

  it "moves polls when a copy is kept in the original topic" do
    original_options = reply_poll.poll_options.to_a

    PostMover.new(source_topic, admin, [reply.id], options: { freeze_original: true }).to_topic(
      destination_topic.id,
    )

    moved_reply = destination_topic.posts.last
    moved_poll = moved_reply.polls.find_by(name: "reply_poll")

    expect(moved_poll).to eq(reply_poll)
    expect(moved_poll.poll_options).to contain_exactly(*original_options)
    expect(moved_poll.poll_votes.map { |vote| [vote.user, vote.poll_option] }).to contain_exactly(
      *original_options.map { |option| [user2, option] },
    )

    expect(moved_reply.custom_fields[DiscoursePoll::HAS_POLLS]).to eq(true)
    expect(Poll.exists?(post_id: reply.id)).to eq(false)
    expect(reply.reload.custom_fields[DiscoursePoll::HAS_POLLS]).to eq(nil)
  end

  it "preserves polls when a reply is moved without creating a new post" do
    source_topic.move_posts(admin, [reply.id], destination_topic_id: destination_topic.id)

    expect(reply.reload.topic_id).to eq(destination_topic.id)

    poll = reply.polls.find_by(name: "reply_poll")
    expect(poll).to eq(reply_poll)
    expect(poll.poll_options).to contain_exactly(*reply_poll.poll_options)
    expect(poll.poll_votes.map { |vote| [vote.user, vote.poll_option] }).to contain_exactly(
      *poll.poll_options.map { |option| [user2, option] },
    )
  end
end

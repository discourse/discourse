# frozen_string_literal: true

RSpec.describe "Chat::Thread replies_count cache accuracy" do
  include ActiveSupport::Testing::TimeHelpers

  fab!(:user) { Fabricate(:user) }
  fab!(:thread) { Fabricate(:chat_thread) }

  it "keeps an accurate replies_count cache" do
    freeze_time
    Jobs.run_immediately!

    expect(thread.replies_count).to eq(0)
    expect(thread.replies_count_cache).to eq(0)

    # Create 5 replies
    5.times do |i|
      Chat::MessageCreator.create(
        chat_channel: thread.channel,
        user: user,
        thread_id: thread.id,
        content: "Hello world #{i}",
      )
    end

    # The job only runs to completion if the cache has not been recently
    # updated, so the DB count will only be 1.
    expect(thread.replies_count_cache).to eq(5)
    expect(thread.reload.replies_count).to eq(1)

    # Travel to the future so the cache expires.
    travel_to 6.minutes.from_now
    Chat::MessageCreator.create(
      chat_channel: thread.channel,
      user: user,
      thread_id: thread.id,
      content: "Hello world now that time has passed",
    )
    expect(thread.replies_count_cache).to eq(6)
    expect(thread.reload.replies_count).to eq(6)

    # Lose the cache intentionally.
    thread.clear_caches!
    message_to_destroy = thread.replies.last
    Chat::TrashMessage.call(
      message_id: message_to_destroy.id,
      channel_id: thread.channel_id,
      guardian: Guardian.new(user),
    )
    expect(thread.replies_count_cache).to eq(5)
    expect(thread.reload.replies_count).to eq(5)

    # Lose the cache intentionally.
    thread.clear_caches!
    Chat::RestoreMessage.call(
      message_id: message_to_destroy.id,
      channel_id: thread.channel_id,
      guardian: Guardian.new(user),
    )
    expect(thread.replies_count_cache).to eq(6)
    expect(thread.reload.replies_count).to eq(6)
  end
end

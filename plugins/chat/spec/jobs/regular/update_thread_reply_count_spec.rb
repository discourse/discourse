# frozen_string_literal: true

RSpec.describe Jobs::Chat::UpdateThreadReplyCount do
  fab!(:thread) { Fabricate(:chat_thread) }
  fab!(:message_1) { Fabricate(:chat_message, thread: thread) }
  fab!(:message_2) { Fabricate(:chat_message, thread: thread) }

  before do
    Chat::Thread.clear_caches!(thread.id)
    SiteSetting.enable_experimental_chat_threaded_discussions = true
  end

  it "does nothing if enable_experimental_chat_threaded_discussions is false" do
    SiteSetting.enable_experimental_chat_threaded_discussions = false
    Chat::Thread.any_instance.expects(:set_replies_count_cache).never
    described_class.new.execute(thread_id: thread.id)
  end

  it "does not error if the thread is deleted" do
    id = thread.id
    thread.destroy!
    expect { described_class.new.execute(thread_id: id) }.not_to raise_error
  end

  it "does not set the reply count in the DB if it has been changed recently" do
    described_class.new.execute(thread_id: thread.id)
    expect(thread.reload.replies_count).to eq(2)
    Fabricate(:chat_message, thread: thread)
    described_class.new.execute(thread_id: thread.id)
    expect(thread.reload.replies_count).to eq(2)
  end

  it "sets the updated_at cache to the current time" do
    freeze_time
    described_class.new.execute(thread_id: thread.id)
    expect(thread.replies_count_cache_updated_at).to eq_time(
      Time.at(Time.zone.now.to_i, in: Time.zone),
    )
  end

  it "publishes the thread original message metadata" do
    messages =
      MessageBus.track_publish("/chat/#{thread.channel_id}") do
        described_class.new.execute(thread_id: thread.id)
      end

    expect(messages.first.data).to eq(
      {
        "original_message_id" => thread.original_message_id,
        "replies_count" => 2,
        "type" => "update_thread_original_message",
        "title" => thread.title,
      },
    )
  end
end

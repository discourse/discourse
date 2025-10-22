# frozen_string_literal: true

RSpec.describe Jobs::Chat::UpdateThreadReplyCount do
  fab!(:thread, :chat_thread)
  fab!(:message_1) { Fabricate(:chat_message, thread: thread) }
  fab!(:message_2) { Fabricate(:chat_message, thread: thread) }

  before { Chat::Thread.clear_caches!(thread.id) }

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
end

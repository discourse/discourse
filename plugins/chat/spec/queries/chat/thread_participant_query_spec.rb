# frozen_string_literal: true

RSpec.describe Chat::ThreadParticipantQuery do
  fab!(:thread_1) { Fabricate(:chat_thread) }
  fab!(:thread_2) { Fabricate(:chat_thread) }
  fab!(:thread_3) { Fabricate(:chat_thread) }

  context "when users have messaged in the thread" do
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:user_3) { Fabricate(:user) }

    before do
      Fabricate(:chat_message, thread: thread_1, user: user_1)
      Fabricate(:chat_message, thread: thread_1, user: user_1)
      Fabricate(:chat_message, thread: thread_1, user: user_1)
      Fabricate(:chat_message, thread: thread_1, user: user_2)
      Fabricate(:chat_message, thread: thread_1, user: user_2)
      Fabricate(:chat_message, thread: thread_1, user: user_3)

      thread_1.add(user_1)
      thread_1.add(user_2)
      thread_1.add(user_3)
    end

    it "has all the user details needed for BasicUserSerializer" do
      result = described_class.call(thread_ids: [thread_1.id, thread_2.id])
      expect(result[thread_1.id][:users].first).to eq(
        {
          id: user_1.id,
          username: user_1.username,
          name: user_1.name,
          uploaded_avatar_id: user_1.uploaded_avatar_id,
        },
      )
    end

    it "returns up to 10 thread participants" do
      result = described_class.call(thread_ids: [thread_1.id])
      expect(result[thread_1.id][:users].length).to eq(4)
    end

    it "calculates the top messagers in a thread as well as the last messager" do
      result = described_class.call(thread_ids: [thread_1.id, thread_2.id])
      expect(result[thread_1.id][:users].map { |u| u[:id] }).to match_array(
        [thread_1.original_message_user_id, user_1.id, user_2.id, user_3.id],
      )
    end

    it "does not count deleted messages for last messager" do
      thread_1.replies.where(user: user_3).each(&:trash!)
      result = described_class.call(thread_ids: [thread_1.id, thread_2.id])
      expect(result[thread_1.id][:users].map { |u| u[:id] }).to eq(
        [user_1.id, thread_1.original_message_user_id, user_2.id],
      )
    end

    it "does not count deleted messages for participation" do
      thread_1.replies.where(user: user_1).each(&:trash!)
      result = described_class.call(thread_ids: [thread_1.id, thread_2.id])
      expect(result[thread_1.id][:users].map { |u| u[:id] }).to eq(
        [user_2.id, thread_1.original_message_user_id, user_3.id],
      )
    end

    it "does not count users who are not members of the thread any longer for participation" do
      thread_1.remove(user_1)
      result = described_class.call(thread_ids: [thread_1.id, thread_2.id])
      expect(result[thread_1.id][:users].map { |u| u[:id] }).to eq(
        [user_2.id, thread_1.original_message_user_id, user_3.id],
      )
    end

    it "calculates the total number of thread participants" do
      result = described_class.call(thread_ids: [thread_1.id, thread_2.id])
      expect(result[thread_1.id][:total_count]).to eq(4)
    end

    it "gets results for both threads" do
      thread_2.add(user_2)
      Fabricate(:chat_message, thread: thread_2, user: user_2)
      Fabricate(:chat_message, thread: thread_2, user: user_2)
      result = described_class.call(thread_ids: [thread_1.id, thread_2.id])
      expect(result[thread_1.id][:users].map { |u| u[:id] }).to match_array(
        [thread_1.original_message_user_id, user_1.id, user_2.id, user_3.id],
      )
      expect(result[thread_2.id][:users].map { |u| u[:id] }).to eq(
        [thread_2.original_message_user_id, user_2.id],
      )
    end
  end

  context "when no one has messaged in either thread but the original message user" do
    it "only returns that user as a participant" do
      result = described_class.call(thread_ids: [thread_1.id, thread_2.id])
      expect(result[thread_1.id][:users].map { |u| u[:id] }).to eq(
        [thread_1.original_message.user_id],
      )
      expect(result[thread_1.id][:total_count]).to eq(1)
      expect(result[thread_2.id][:users].map { |u| u[:id] }).to eq(
        [thread_2.original_message.user_id],
      )
      expect(result[thread_2.id][:total_count]).to eq(1)
    end
  end

  context "when using preview false" do
    1..9.times do |i|
      user = "user_#{i}".to_sym
      fab!(user) { Fabricate(:user) }
    end

    before do
      1..9.times do |i|
        user = "user_#{i}".to_sym
        thread_3.add(public_send(user))
        Fabricate(:chat_message, thread: thread_3, user: public_send(user))
      end
    end

    it "does not return more than 10 thread participants" do
      other_user = Fabricate(:user)
      thread_3.add(other_user)
      Fabricate(:chat_message, thread: thread_3, user: other_user)
      result = described_class.call(thread_ids: [thread_3.id])
      expect(result[thread_3.id][:users].length).to eq(10)
    end
  end
end

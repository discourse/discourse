# frozen_string_literal: true

RSpec.describe Jobs::Chat::DeleteUserMessages do
  describe "#execute" do
    fab!(:user_1) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel) }
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: channel, user: user_1) }

    it "deletes messages from the user" do
      subject.execute(user_id: user_1)

      expect { chat_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "doesn't delete messages from other users" do
      user_2 = Fabricate(:user)
      user_2_message = Fabricate(:chat_message, chat_channel: channel, user: user_2)

      subject.execute(user_id: user_1)

      expect(user_2_message.reload).to be_present
    end

    it "deletes trashed messages" do
      chat_message.trash!

      subject.execute(user_id: user_1)

      expect(Chat::Message.with_deleted.where(id: chat_message.id)).to be_empty
    end
  end
end

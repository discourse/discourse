# frozen_string_literal: true

describe Jobs::Chat::ProcessMessage do
  fab!(:chat_message) { Fabricate(:chat_message, message: "https://discourse.org/team") }

  before do
    stub_request(:get, "https://discourse.org/team").to_return(
      status: 200,
      body: "<html><head><title>a</title></head></html>",
    )

    stub_request(:head, "https://discourse.org/team").to_return(status: 200)
  end

  it "updates cooked with oneboxes" do
    described_class.new.execute(chat_message_id: chat_message.id)
    expect(chat_message.reload.cooked).to eq(
      "<p><a href=\"https://discourse.org/team\" class=\"onebox\" target=\"_blank\" rel=\"noopener nofollow ugc\">https://discourse.org/team</a></p>",
    )
  end

  context "when the cooked message changed" do
    it "publishes the update" do
      chat_message.update!(cooked: "another lovely cat")
      Chat::Publisher.expects(:publish_processed!).once
      described_class.new.execute(chat_message_id: chat_message.id)
    end
  end

  it "does not error when message is deleted" do
    chat_message.destroy
    expect { described_class.new.execute(chat_message_id: chat_message.id) }.not_to raise_exception
  end
end

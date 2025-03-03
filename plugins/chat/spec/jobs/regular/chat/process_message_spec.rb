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
      "<aside class=\"onebox allowlistedgeneric\" data-onebox-src=\"https://discourse.org/team\">\n  <header class=\"source\">\n\n      <a href=\"https://discourse.org/team\" target=\"_blank\" rel=\"nofollow ugc noopener\">discourse.org</a>\n  </header>\n\n  <article class=\"onebox-body\">\n    \n\n<h3><a href=\"https://discourse.org/team\" target=\"_blank\" rel=\"nofollow ugc noopener\">a</a></h3>\n\n\n\n  </article>\n\n  <div class=\"onebox-metadata\">\n    \n    \n  </div>\n\n  <div style=\"clear: both\"></div>\n</aside>\n",
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

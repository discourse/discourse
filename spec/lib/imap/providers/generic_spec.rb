# frozen_string_literal: true

RSpec.describe Imap::Providers::Generic do
  fab!(:username) { "test@generic.com" }
  fab!(:password) { "test1!" }
  fab!(:provider) do
    described_class.new(
      "imap.generic.com",
      { port: 993, ssl: true, username: username, password: password },
    )
  end
  let(:dummy_mailboxes) do
    [
      Net::IMAP::MailboxList.new([], "/", "All Mail"),
      Net::IMAP::MailboxList.new([:Noselect], "/", "Other"),
      Net::IMAP::MailboxList.new([:Trash], "/", "Bin"),
    ]
  end

  let(:imap_stub) { stub }
  before { described_class.any_instance.stubs(:imap).returns(imap_stub) }

  describe "#connect!" do
    it "calls login with the provided username and password on the imap client" do
      imap_stub.expects(:login).with(username, password).once
      provider.connect!
    end
  end

  describe "#list_mailboxes" do
    before { imap_stub.expects(:list).with("", "*").returns(dummy_mailboxes) }

    it "does not return any mailboxes with the Noselect attribute" do
      expect(provider.list_mailboxes).not_to include("Other")
    end

    it "filters by the provided attribute" do
      expect(provider.list_mailboxes(:Trash)).to eq(["Bin"])
    end

    it "lists all mailboxes names" do
      expect(provider.list_mailboxes).to eq(["All Mail", "Bin"])
    end
  end

  describe "#trash_mailbox" do
    before do
      imap_stub.expects(:list).with("", "*").returns(dummy_mailboxes)
      Discourse.cache.delete("imap_trash_mailbox_#{provider.account_digest}")
    end

    it "returns the mailbox with the special-use attribute \Trash" do
      expect(provider.trash_mailbox).to eq("Bin")
    end

    it "caches the result based on the account username and server for 30 mins" do
      provider.trash_mailbox
      provider.expects(:list_mailboxes).never
      provider.trash_mailbox
    end
  end

  describe "#find_trashed_by_message_ids" do
    before do
      provider.stubs(:trash_mailbox).returns("Bin")
      imap_stub.stubs(:examine).with("Inbox").twice
      imap_stub.stubs(:responses).returns({ "UIDVALIDITY" => [1] })
      imap_stub.stubs(:examine).with("Bin")
      imap_stub.stubs(:responses).returns({ "UIDVALIDITY" => [9] })
      provider
        .expects(:emails)
        .with([4, 6], %w[UID ENVELOPE])
        .returns(
          [
            { "ENVELOPE" => stub(message_id: "<h4786x34@test.com>"), "UID" => 4 },
            { "ENVELOPE" => stub(message_id: "<f349xj84@test.com>"), "UID" => 6 },
          ],
        )
    end

    let(:message_ids) { %w[h4786x34@test.com dvsfuf39@test.com f349xj84@test.com] }

    it "sends the message-id search in the correct format and returns the trashed emails and UIDVALIDITY" do
      provider.open_mailbox("Inbox")
      imap_stub
        .expects(:uid_search)
        .with(
          "OR OR HEADER Message-ID '<h4786x34@test.com>' HEADER Message-ID '<dvsfuf39@test.com>' HEADER Message-ID '<f349xj84@test.com>'",
        )
        .returns([4, 6])
      resp = provider.find_trashed_by_message_ids(message_ids)

      expect(resp.trashed_emails.map(&:message_id)).to match_array(
        %w[h4786x34@test.com f349xj84@test.com],
      )
      expect(resp.trash_uid_validity).to eq(9)
    end
  end

  describe "#trash" do
    it "stores the \Deleted flag on the UID and expunges" do
      provider.stubs(:can?).with("MOVE").returns(false)
      provider.expects(:store).with(78, "FLAGS", [], ['\Deleted'])
      imap_stub.expects(:expunge)
      provider.trash(78)
    end

    context "if the server supports MOVE" do
      it "calls trash_move which is implemented by the provider" do
        provider.stubs(:can?).with("MOVE").returns(true)
        provider.expects(:trash_move).with(78)
        provider.trash(78)
      end
    end
  end

  describe "#uids" do
    it "can search with from and to" do
      imap_stub.expects(:uid_search).once.with("UID 5:9")
      provider.uids(from: 5, to: 9)
    end

    it "can search with only from" do
      imap_stub.expects(:uid_search).once.with("UID 5:*")
      provider.uids(from: 5)
    end

    it "can search with only to" do
      imap_stub.expects(:uid_search).once.with("UID 1:9")
      provider.uids(to: 9)
    end

    it "can search all" do
      imap_stub.expects(:uid_search).once.with("ALL")
      provider.uids
    end
  end

  describe "#open_mailbox" do
    it "uses examine to get a readonly version of the mailbox" do
      imap_stub.expects(:examine).with("Inbox")
      imap_stub.expects(:responses).returns({ "UIDVALIDITY" => [1] })
      provider.open_mailbox("Inbox")
    end

    describe "write true" do
      context "if imap_write is disabled" do
        before { SiteSetting.enable_imap_write = false }

        it "raises an error" do
          expect { provider.open_mailbox("Inbox", write: true) }.to raise_error(
            Imap::Providers::WriteDisabledError,
          )
        end
      end

      context "if imap_write is enabled" do
        before { SiteSetting.enable_imap_write = true }

        it "does not raise an error and calls imap.select" do
          imap_stub.expects(:select).with("Inbox")
          imap_stub.expects(:responses).returns({ "UIDVALIDITY" => [1] })
          expect { provider.open_mailbox("Inbox", write: true) }.not_to raise_error
        end
      end
    end
  end

  describe "#emails" do
    let(:fields) { ["UID"] }
    let(:uids) { [99, 106] }

    it "returns empty array if uid_fetch does not find any matching emails by uid" do
      imap_stub.expects(:uid_fetch).with(uids, fields).returns(nil)
      expect(provider.emails(uids, fields)).to eq([])
    end

    it "returns an array of attributes" do
      imap_stub
        .expects(:uid_fetch)
        .with(uids, fields)
        .returns(
          [
            Net::IMAP::FetchData.new(1, { "UID" => 99 }),
            Net::IMAP::FetchData.new(1, { "UID" => 106 }),
          ],
        )
      expect(provider.emails(uids, fields)).to eq([{ "UID" => 99 }, { "UID" => 106 }])
    end
  end

  describe "#to_tag" do
    it "returns a label cleaned up so it can be used for a discourse tag" do
      expect(provider.to_tag("Some Label")).to eq("some-label")
    end
  end

  describe "#tag_to_label" do
    it "returns the tag as is by default" do
      expect(provider.tag_to_label("Support")).to eq("Support")
    end
  end
end

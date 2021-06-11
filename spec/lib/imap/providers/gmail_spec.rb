
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Imap::Providers::Gmail do
  fab!(:username) { "test@generic.com" }
  fab!(:password) { "test1!" }
  fab!(:provider) do
    described_class.new(
      "imap.generic.com",
      {
        port: 993,
        ssl: true,
        username: username,
        password: password
      }
    )
  end

  let(:imap_stub) { stub }
  let(:x_gm_thrid) { Imap::Providers::Gmail::X_GM_THRID }
  let(:x_gm_labels) { Imap::Providers::Gmail::X_GM_LABELS }
  before do
    described_class.any_instance.stubs(:imap).returns(imap_stub)
  end

  describe "#store" do
    it "converts LABELS store to special X-GM-LABELS" do
      Imap::Providers::Generic.any_instance.expects(:store).with(
        63, x_gm_labels, ["\\Inbox"], ["\\Inbox", "test"]
      )
      provider.store(63, "LABELS", ["\\Inbox"], ["\\Inbox", "test"])
    end
  end

  describe "#tag_to_label" do
    it "converts important to special gmail label \\Important" do
      expect(provider.tag_to_label("important")).to eq("\\Important")
    end

    it "converts starred to special gmail label \\Starred" do
      expect(provider.tag_to_label("starred")).to eq("\\Starred")
    end
  end

  describe "#archive" do
    it "gets the thread ID for the UID, and removes the Inbox label from all UIDs in the thread" do
      main_uid = 78
      fake_thrid = '4398634986239754'
      imap_stub.expects(:uid_fetch).with(main_uid, [x_gm_thrid]).returns(
        [stub(attr: { x_gm_thrid => fake_thrid })]
      )
      imap_stub.expects(:uid_search).with("#{x_gm_thrid} #{fake_thrid}").returns([79, 80])
      provider.expects(:emails).with([79, 80], ["UID", "LABELS"]).returns(
        [
          {
            "UID" => 79,
            "LABELS" => ["\\Inbox", "seen"]
          },
          {
            "UID" => 80,
            "LABELS" => ["\\Inbox", "seen"]
          }
        ]
      )
      provider.expects(:store).with(79, "LABELS", ["\\Inbox", "seen"], ["seen"])
      provider.expects(:store).with(80, "LABELS", ["\\Inbox", "seen"], ["seen"])

      provider.archive(main_uid)
    end
  end

  describe "#filter_mailboxes" do
    it "filters down the gmail mailboxes to only show the relevant ones" do
      mailboxes_with_attr = [
        Net::IMAP::MailboxList.new([:Hasnochildren], "/", "INBOX"),
        Net::IMAP::MailboxList.new([:All, :Hasnochildren], "/", "[Gmail]/All Mail"),
        Net::IMAP::MailboxList.new([:Drafts, :Hasnochildren], "/", "[Gmail]/Drafts"),
        Net::IMAP::MailboxList.new([:Hasnochildren, :Important], "/", "[Gmail]/Important"),
        Net::IMAP::MailboxList.new([:Hasnochildren, :Sent], "/", "[Gmail]/Sent Mail"),
        Net::IMAP::MailboxList.new([:Hasnochildren, :Junk], "/", "[Gmail]/Spam"),
        Net::IMAP::MailboxList.new([:Flagged, :Hasnochildren], "/", "[Gmail]/Starred"),
        Net::IMAP::MailboxList.new([:Hasnochildren, :Trash], "/", "[Gmail]/Trash")
      ]

      expect(provider.filter_mailboxes(mailboxes_with_attr)).to match_array([
        "INBOX", "[Gmail]/All Mail", "[Gmail]/Important"
      ])
    end
  end
end

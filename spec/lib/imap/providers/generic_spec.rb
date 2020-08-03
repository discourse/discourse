# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Imap::Providers::Generic do
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
  before do
    described_class.any_instance.stubs(:imap).returns(imap_stub)
  end

  describe "#connect!" do
    it "calls login with the provided username and password on the imap client" do
      imap_stub.expects(:login).with(username, password).once
      provider.connect!
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
      imap_stub.expects(:responses).returns({ 'UIDVALIDITY' => [1] })
      provider.open_mailbox("Inbox")
    end

    describe "write true" do
      context "if imap_write is disabled" do
        before { SiteSetting.enable_imap_write = false }

        it "raises an error" do
          expect { provider.open_mailbox("Inbox", write: true) }.to raise_error(
            Imap::Providers::WriteDisabledError
          )
        end
      end

      context "if imap_write is enabled" do
        before { SiteSetting.enable_imap_write = true }

        it "does not raise an error and calls imap.select" do
          imap_stub.expects(:select).with("Inbox")
          imap_stub.expects(:responses).returns({ 'UIDVALIDITY' => [1] })
          expect { provider.open_mailbox("Inbox", write: true) }.not_to raise_error
        end
      end
    end
  end

  describe "#emails" do
    let(:fields) { ['UID'] }
    let(:uids) { [99, 106] }

    it "returns empty array if uid_fetch does not find any matching emails by uid" do
      imap_stub.expects(:uid_fetch).with(uids, fields).returns(nil)
      expect(provider.emails(uids, fields)).to eq([])
    end

    it "returns an array of attributes" do
      imap_stub.expects(:uid_fetch).with(uids, fields).returns([
        Net::IMAP::FetchData.new(1, { "UID" => 99 }),
        Net::IMAP::FetchData.new(1, { "UID" => 106 })
      ])
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

require 'rails_helper'
require 'imap'
require_relative 'imap_helper'

describe Imap::Sync do
  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.allow_staff_to_tag_pms = true
  end

  context "GMAIL provider" do
    # let(:sync_handler) { Imap::Sync.new(group, Imap::Providers::Gmail) }
    let(:sync_handler) { Imap::Sync.new(group, MockedImapProvider) }

    let(:group) {
      Fabricate(:group,
        email_imap_server: "imap.gmail.com",
        email_username: "weareyodateam@gmail.com",
        email_password: "yodateam123"
      )
    }

    let(:mailbox) {
      Fabricate(:mailbox, name: "[Gmail]/All Mail", sync: true, group_id: group.id)
    }

    before do
      group.update!(mailboxes: [mailbox])
    end

    context "creates topic from email with no previous sync" do
      let(:email_sender) { "john@free.fr" }
      let(:email_subject) { "Testing email post" }

      before do
        provider = MockedImapProvider.any_instance
        provider.stubs(:labels).returns(["INBOX"])
        provider.stubs(:mailbox_status).returns(uid_validity: 1)
        provider.stubs(:all_uids).returns([1])
        provider.stubs(:uids_until).returns([1])
        provider.stubs(:uids_from).returns([])
        provider.stubs(:emails).returns([
          {
            "UID" => 1,
            "LABELS" => ["\\Important", "test-label"],
            "FLAGS" => [:Seen],
            "RFC822" => EmailFabricator(from: email_sender, subject: email_subject)
          }
        ])

        group.mailboxes.where(sync: true).each do |mailbox|
          sync_handler.process(mailbox)
        end

        @topic = Topic.last
      end

      it "creates a topic" do
        expect(Topic.count).to eq(1)

        expect(@topic.title).to eq(email_subject)
        expect(@topic.user.email).to eq(email_sender)
      end

      it "it doesn’t create a topic twice" do
        group.mailboxes.where(sync: true).each do |mailbox|
          sync_handler.process(mailbox)
        end

        expect(Topic.count).to eq(1)
      end

      it "applies tags" do
        expect(@topic.tags.pluck(:name)).to eq(["seen", "important", "test-label"])
      end
    end

    context "creates topic from email with no previous sync" do
      let(:first_email_sender) { "john@free.fr" }
      let(:first_email_subject) { "Testing email post" }
      let(:second_email_sender) { "sam@free.fr" }
      let(:second_email_subject) { "Responding to email post" }

      it "creates a topic" do
        provider = MockedImapProvider.any_instance
        provider.stubs(:labels).returns(["INBOX"])
        provider.stubs(:mailbox_status).returns(uid_validity: 1)
        provider.stubs(:all_uids).returns([1])
        provider.stubs(:emails).returns([
          {
            "UID" => 1,
            "LABELS" => ["\\Inbox", "test-label"],
            "FLAGS" => [:Recent],
            "RFC822" => EmailFabricator(from: first_email_sender, subject: first_email_subject)
          }
        ])

        expect(Topic.count).to eq(0)

        group.mailboxes.where(sync: true).each do |mailbox|
          sync_handler.process(mailbox)
        end

        expect(Topic.count).to eq(1)

        @topic = Topic.last

        expect(@topic.posts.where('posts.post_type IN (?)', Post.types[:regular]).count).to eq(1)
        expect(@topic.title).to eq(first_email_subject)
        expect(@topic.user.email).to eq(first_email_sender)

        provider = MockedImapProvider.any_instance
        provider.stubs(:labels).returns(["INBOX"])
        provider.stubs(:mailbox_status).returns(uid_validity: 1)
        provider.stubs(:uids_until).returns([1])
        provider.stubs(:uids_from).returns([2])
        provider.stubs(:emails).with([1], ["UID", "FLAGS", "LABELS"]).returns([
          {
            "UID" => 1,
            "LABELS" => ["\\Inbox", "test-label"],
            "FLAGS" => [:Seen],
            "RFC822" => EmailFabricator(from: first_email_sender, subject: first_email_subject)
          }
        ])
        provider.stubs(:emails).with([2], ["UID", "FLAGS", "LABELS", "RFC822"]).returns([
          {
            "UID" => 2,
            "LABELS" => ["\\Inbox", "test-label"],
            "FLAGS" => [:Recent],
            "RFC822" => EmailFabricator(from: second_email_sender, subject: second_email_subject)
          }
        ])

        group.mailboxes.where(sync: true).each do |mailbox|
          sync_handler.process(mailbox)
        end

        @topic.reload

        # posts = @topic.posts.where('posts.post_type IN (?)', Post.types[:regular]).by_post_number
        #
        # expect(Topic.count).to eq(1)
        # expect(posts.count).to eq(2)
        #
        # expect(@topic.title).to eq(first_email_subject)
        # expect(@topic.user.email).to eq(first_email_sender)
        #
        # post = posts.last
        #
        # p post.user
      end
    end
  end
end

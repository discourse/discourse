require 'rails_helper'
require 'imap'
require_relative 'imap_helper'

describe Imap::Sync do
  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.allow_staff_to_tag_pms = true
    SiteSetting.imap_read_only = true
    Jobs.run_immediately!
  end

  context "GMAIL provider" do
    let(:sync_handler) { Imap::Sync.new(group, provider: MockedImapProvider) }

    let(:group) {
      Fabricate(:group,
        imap_server: "imap.gmail.com",
        email_username: "xxx",
        email_password: "zzz"
      )
    }

    let!(:mailbox) {
      Fabricate(:mailbox, group: group, name: "[Gmail]/All Mail", sync: true)
    }

    context "creates topic from email with no previous sync" do
      let(:email_sender) { "john@free.fr" }
      let(:email_subject) { "Testing email post" }

      before do
        provider = MockedImapProvider.any_instance
        provider.stubs(:open_mailbox).returns(uid_validity: 1)
        provider.stubs(:uids).with().returns([1])
        provider.stubs(:uids).with(to: 1).returns([1])
        provider.stubs(:uids).with(from: 2).returns([])
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

    context "creates topic and posts from email with multiple exchanges" do
      let(:first_email_sender) { "john@free.fr" }
      let(:second_email_sender) { "sam@free.fr" }
      let(:email_subject) { "Testing email post" }
      let(:first_body) { "This is the first message of this exchange." }
      let(:second_body) { "<p>This is an <b>answer</b> to this message.</p>" }

      before do
        provider = MockedImapProvider.any_instance
        provider.stubs(:open_mailbox).returns(uid_validity: 1)
        provider.stubs(:uids).with().returns([1, 2])
        provider.stubs(:emails).returns([
          {
            "UID" => 1,
            "LABELS" => ["\\Inbox"],
            "FLAGS" => [:Seen],
            "RFC822" => EmailFabricator(
              message_id: "<x@gmail.com>",
              from: second_email_sender,
              to: first_email_sender,
              subject: email_subject,
              body: first_body
            )
          },
          {
            "UID" => 2,
            "LABELS" => ["\\Inbox"],
            "FLAGS" => [:Recent],
            "RFC822" => EmailFabricator(
              message_id: "<y@gmail.com>",
              in_reply_to: "<x@gmail.com>",
              from: first_email_sender,
              to: second_email_sender,
              subject: "Re: #{email_subject}",
              body: second_body
            )
          }
        ])

        group.mailboxes.where(sync: true).each do |mailbox|
          sync_handler.process(mailbox)
        end

        @topic = Topic.last
        @posts = @topic.posts.where('posts.post_type IN (?)', Post.types[:regular]).by_post_number
      end

      it "creates a topic with posts" do
        expect(Topic.count).to eq(1)
        expect(@posts.count).to eq(2)
      end

      it "has the correct topic infos" do
        expect(@topic.archived).to eq(false)
        expect(@topic.user.email).to eq(second_email_sender)
        expect(@topic.title).to eq(email_subject)
      end

      it "has the correct post infos" do
        first_post = @posts[0]
        expect(first_post.user.email).to eq(second_email_sender)
        expect(first_post.raw).to eq(first_body)

        second_post = @posts[1]
        expect(second_post.user.email).to eq(first_email_sender)
        expect(second_post.raw).to eq(second_body)
      end
    end
  end
end

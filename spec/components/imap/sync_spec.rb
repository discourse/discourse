require "rails_helper"
require "imap"
require_relative "imap_helper"

describe Imap::Sync do

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.allow_staff_to_tag_pms = true

    SiteSetting.enable_imap = true

    Jobs.run_immediately!
  end

  let(:group) do
    Fabricate(
      :group,
      imap_server: "imap.gmail.com",
      imap_port: 993,
      email_username: "discourse@example.com",
      email_password: "discourse@example.com"
    )
  end

  let(:mailbox) { Fabricate(:mailbox, group: group, name: "[Gmail]/All Mail", sync: true) }

  let(:sync_handler) { Imap::Sync.new(group, provider: MockedImapProvider) }

  context "no previous sync" do
    let(:from) { "john@free.fr" }
    let(:subject) { "Testing email post" }
    let(:message_id) { "#{SecureRandom.hex}@example.com" }

    let(:email) do
      EmailFabricator(
        from: from,
        to: group.email_username,
        subject: subject,
        message_id: message_id)
    end

    before do
      provider = MockedImapProvider.any_instance
      provider.stubs(:open_mailbox).returns(uid_validity: 1)
      provider.stubs(:uids).with.returns([100])
      provider.stubs(:uids).with(to: 100).returns([100])
      provider.stubs(:uids).with(from: 101).returns([])
      provider.stubs(:emails).returns(
        [
          {
            "UID" => 100,
            "LABELS" => %w[\\Important test-label],
            "FLAGS" => %i[Seen],
            "RFC822" => email
          }
        ]
      )
    end

    it "creates a topic from an incoming email" do
      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(1)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(1)
        .and change { IncomingEmail.count }.by(1)

      expect(mailbox.uid_validity).to eq(1)
      expect(mailbox.last_seen_uid).to eq(100)

      topic = Topic.last
      expect(topic.title).to eq(subject)
      expect(topic.user.email).to eq(from)
      expect(topic.tags.pluck(:name)).to eq(%w[seen important test-label])

      post = topic.posts.first
      expect(post.raw).to eq("This is an email *body*. :smile:")

      incoming_email = post.incoming_email
      expect(incoming_email.raw).to eq(email)
      expect(incoming_email.message_id).to eq(message_id)
      expect(incoming_email.from_address).to eq(from)
      expect(incoming_email.to_addresses).to eq(group.email_username)
      expect(incoming_email.imap_uid_validity).to eq(1)
      expect(incoming_email.imap_uid).to eq(100)
      expect(incoming_email.imap_sync).to eq(false)
    end

    it "does not duplicate topics" do
      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(1)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(1)
        .and change { IncomingEmail.count }.by(1)

      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(0)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(0)
        .and change { IncomingEmail.count }.by(0)
    end

    it "does not duplicate incoming emails" do
      incoming_email = Fabricate(:incoming_email, message_id: message_id)

      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(0)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(0)
        .and change { IncomingEmail.count }.by(0)

      incoming_email.reload
      expect(incoming_email.message_id).to eq(message_id)
      expect(incoming_email.imap_uid_validity).to eq(1)
      expect(incoming_email.imap_uid).to eq(100)
      expect(incoming_email.imap_sync).to eq(false)
    end
  end

  context "previous sync" do
    let(:subject) { "Testing email post" }

    let(:first_from) { "john@free.fr" }
    let(:first_message_id) { SecureRandom.hex }
    let(:first_body) { "This is the first message of this exchange." }

    let(:second_from) { "sam@free.fr" }
    let(:second_message_id) { SecureRandom.hex }
    let(:second_body) { "<p>This is an <b>answer</b> to this message.</p>" }

    it "continues with new emails" do
      provider = MockedImapProvider.any_instance
      provider.stubs(:open_mailbox).returns(uid_validity: 1)

      provider.stubs(:uids).with.returns([100])
      provider.stubs(:emails).with(anything, [100], anything).returns(
        [
          {
            "UID" => 100,
            "LABELS" => %w[\\Inbox],
            "FLAGS" => %i[Seen],
            "RFC822" => EmailFabricator(
              message_id: first_message_id,
              from: first_from,
              to: group.email_username,
              cc: second_from,
              subject: subject,
              body: first_body
            )
          }
        ]
      )

      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(1)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(1)
        .and change { IncomingEmail.count }.by(1)

      topic = Topic.last
      expect(topic.title).to eq(subject)
      expect(GroupArchivedMessage.where(topic_id: topic.id).exists?).to eq(false)

      post = Post.where(post_type: Post.types[:regular]).last
      expect(post.user.email).to eq(first_from)
      expect(post.raw).to eq(first_body)
      expect(mailbox.uid_validity).to eq(1)
      expect(mailbox.last_seen_uid).to eq(100)

      provider.stubs(:uids).with(to: 100).returns([100])
      provider.stubs(:uids).with(from: 101).returns([200])
      provider.stubs(:emails).with(anything, [100], anything).returns(
        [
          {
            "UID" => 100,
            "LABELS" => %w[\\Inbox],
            "FLAGS" => %i[Seen]
          }
        ]
      )
      provider.stubs(:emails).with(anything, [200], anything).returns(
        [
          {
            "UID" => 200,
            "LABELS" => %w[\\Inbox],
            "FLAGS" => %i[Recent],
            "RFC822" => EmailFabricator(
              message_id: SecureRandom.hex,
              in_reply_to: first_message_id,
              from: second_from,
              to: group.email_username,
              subject: "Re: #{subject}",
              body: second_body
            )
          }
        ]
      )

      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(0)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(1)
        .and change { IncomingEmail.count }.by(1)

      post = Post.where(post_type: Post.types[:regular]).last
      expect(post.user.email).to eq(second_from)
      expect(post.raw).to eq(second_body)
      expect(mailbox.uid_validity).to eq(1)
      expect(mailbox.last_seen_uid).to eq(200)

      provider.stubs(:uids).with(to: 200).returns([100, 200])
      provider.stubs(:uids).with(from: 201).returns([])
      provider.stubs(:emails).with(anything, [100, 200], anything).returns(
        [
          {
            "UID" => 100,
            "LABELS" => %w[],
            "FLAGS" => %i[Seen]
          },
          {
            "UID" => 200,
            "LABELS" => %w[],
            "FLAGS" => %i[Recent],
          }
        ]
      )

      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(0)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(0)
        .and change { IncomingEmail.count }.by(0)

      topic = Topic.last
      expect(topic.title).to eq(subject)
      expect(GroupArchivedMessage.where(topic_id: topic.id).exists?).to eq(true)

      expect(Topic.last.posts.where(post_type: Post.types[:regular]).count).to eq(2)
    end
  end

  context "invaidated previous sync" do
    let(:subject) { "Testing email post" }

    let(:first_from) { "john@free.fr" }
    let(:first_message_id) { SecureRandom.hex }
    let(:first_body) { "This is the first message of this exchange." }

    let(:second_from) { "sam@free.fr" }
    let(:second_message_id) { SecureRandom.hex }
    let(:second_body) { "<p>This is an <b>answer</b> to this message.</p>" }

    it "is updated" do
      provider = MockedImapProvider.any_instance

      provider.stubs(:open_mailbox).returns(uid_validity: 1)
      provider.stubs(:uids).with.returns([100, 200])
      provider.stubs(:emails).with(anything, [100, 200], anything).returns(
        [
          {
            "UID" => 100,
            "LABELS" => %w[\\Inbox],
            "FLAGS" => %i[Seen],
            "RFC822" => EmailFabricator(
              message_id: first_message_id,
              from: first_from,
              to: group.email_username,
              cc: second_from,
              subject: subject,
              body: first_body
            )
          },
          {
            "UID" => 200,
            "LABELS" => %w[\\Inbox],
            "FLAGS" => %i[Recent],
            "RFC822" => EmailFabricator(
              message_id: second_message_id,
              in_reply_to: first_message_id,
              from: second_from,
              to: group.email_username,
              subject: "Re: #{subject}",
              body: second_body
            )
          }
        ]
      )

      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(1)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(2)
        .and change { IncomingEmail.count }.by(2)

      imap_data = Topic.last.incoming_email.pluck(:imap_uid_validity, :imap_uid)
      expect(imap_data.first).to eq([1, 100])
      expect(imap_data.second).to eq([1, 200])

      provider.stubs(:open_mailbox).returns(uid_validity: 2)
      provider.stubs(:uids).with.returns([111, 222])
      provider.stubs(:emails).with(anything, [111, 222], anything).returns(
        [
          {
            "UID" => 111,
            "LABELS" => %w[\\Inbox],
            "FLAGS" => %i[Seen],
            "RFC822" => EmailFabricator(
              message_id: first_message_id,
              from: first_from,
              to: group.email_username,
              cc: second_from,
              subject: subject,
              body: first_body
            )
          },
          {
            "UID" => 222,
            "LABELS" => %w[\\Inbox],
            "FLAGS" => %i[Recent],
            "RFC822" => EmailFabricator(
              message_id: second_message_id,
              in_reply_to: first_message_id,
              from: second_from,
              to: group.email_username,
              subject: "Re: #{subject}",
              body: second_body
            )
          }
        ]
      )

      expect { sync_handler.process(mailbox) }
        .to change { Topic.count }.by(0)
        .and change { Post.where(post_type: Post.types[:regular]).count }.by(0)
        .and change { IncomingEmail.count }.by(0)

      imap_data = Topic.last.incoming_email.pluck(:imap_uid_validity, :imap_uid)
      expect(imap_data.first).to eq([2, 111])
      expect(imap_data.second).to eq([2, 222])
    end
  end
end

# frozen_string_literal: true

require "imap/sync"

RSpec.describe Imap::Sync do
  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.pm_tags_allowed_for_groups = "1|2|3"

    SiteSetting.enable_imap = true

    Jobs.run_immediately!
  end

  let(:group) do
    Fabricate(
      :group,
      imap_server: "imap.gmail.com",
      imap_port: 993,
      email_username: "groupemailusername@example.com",
      email_password: "password",
      imap_mailbox_name: "[Gmail]/All Mail",
    )
  end

  let(:sync_handler) { Imap::Sync.new(group) }

  before do
    mocked_imap_provider =
      MockedImapProvider.new(
        group.imap_server,
        port: group.imap_port,
        ssl: group.imap_ssl,
        username: group.email_username,
        password: group.email_password,
      )
    Imap::Providers::Detector.stubs(:init_with_detected_provider).returns(mocked_imap_provider)
  end

  describe "no previous sync" do
    let(:from) { "john@free.fr" }
    let(:email_subject) { "Testing email post" }
    let(:message_id) { "#{SecureRandom.hex}@example.com" }

    let(:email) do
      EmailFabricator(
        from: from,
        to: group.email_username,
        subject: email_subject,
        message_id: message_id,
      )
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
            "RFC822" => email,
          },
        ],
      )
    end

    it "creates a topic from an incoming email" do
      expect { sync_handler.process }.to change { Topic.count }.by(1).and change {
              Post.where(post_type: Post.types[:regular]).count
            }.by(1).and change { IncomingEmail.count }.by(1)

      expect(IncomingEmail.last.created_via).to eq(IncomingEmail.created_via_types[:imap])

      expect(group.imap_uid_validity).to eq(1)
      expect(group.imap_last_uid).to eq(100)

      topic = Topic.last
      expect(topic.title).to eq(email_subject)
      expect(topic.user.email).to eq(from)
      expect(topic.tags.pluck(:name)).to contain_exactly("seen", "important", "test-label")

      post = topic.first_post
      expect(post.raw).to eq("This is an email *body*. :smile:")

      incoming_email = post.incoming_email
      expect(incoming_email.raw.lines.map(&:strip)).to eq(email.lines.map(&:strip))
      expect(incoming_email.message_id).to eq(message_id)
      expect(incoming_email.from_address).to eq(from)
      expect(incoming_email.to_addresses).to eq(group.email_username)
      expect(incoming_email.imap_uid_validity).to eq(1)
      expect(incoming_email.imap_uid).to eq(100)
      expect(incoming_email.imap_sync).to eq(false)
      expect(incoming_email.imap_group_id).to eq(group.id)
    end

    context "when tagging not enabled" do
      before { SiteSetting.tagging_enabled = false }

      it "creates a topic from an incoming email but with no tags added" do
        expect { sync_handler.process }.to change { Topic.count }.by(1).and change {
                Post.where(post_type: Post.types[:regular]).count
              }.by(1).and change { IncomingEmail.count }.by(1)

        expect(group.imap_uid_validity).to eq(1)
        expect(group.imap_last_uid).to eq(100)

        topic = Topic.last
        expect(topic.title).to eq(email_subject)
        expect(topic.user.email).to eq(from)
        expect(topic.tags).to eq([])
      end
    end

    it "does not duplicate topics" do
      expect { sync_handler.process }.to change { Topic.count }.by(1).and change {
              Post.where(post_type: Post.types[:regular]).count
            }.by(1).and change { IncomingEmail.count }.by(1)

      expect { sync_handler.process }.to not_change { Topic.count }.and not_change {
              Post.where(post_type: Post.types[:regular]).count
            }.and not_change { IncomingEmail.count }
    end

    it "creates a new incoming email if the message ID does not match the receiver post id regex" do
      incoming_email = Fabricate(:incoming_email, message_id: message_id)

      expect { sync_handler.process }.to change { Topic.count }.by(1).and change {
              Post.where(post_type: Post.types[:regular]).count
            }.by(1).and change { IncomingEmail.count }.by(1)

      last_incoming = IncomingEmail.where(message_id: message_id).last
      expect(last_incoming.message_id).to eq(message_id)
      expect(last_incoming.imap_uid_validity).to eq(1)
      expect(last_incoming.imap_uid).to eq(100)
      expect(last_incoming.imap_sync).to eq(false)
      expect(last_incoming.imap_group_id).to eq(group.id)
    end

    context "when the message id matches the receiver post id regex" do
      let(:message_id) { "discourse/post/324@test.localhost" }
      it "does not duplicate incoming email" do
        incoming_email = Fabricate(:incoming_email, message_id: message_id)

        expect { sync_handler.process }.to not_change { Topic.count }.and not_change {
                Post.where(post_type: Post.types[:regular]).count
              }.and not_change { IncomingEmail.count }

        incoming_email.reload
        expect(incoming_email.message_id).to eq(message_id)
        expect(incoming_email.imap_uid_validity).to eq(1)
        expect(incoming_email.imap_uid).to eq(100)
        expect(incoming_email.imap_sync).to eq(false)
        expect(incoming_email.imap_group_id).to eq(group.id)
      end
    end
  end

  describe "previous sync" do
    let(:email_subject) { "Testing email post" }

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
      provider
        .stubs(:emails)
        .with([100], %w[UID FLAGS LABELS RFC822], anything)
        .returns(
          [
            {
              "UID" => 100,
              "LABELS" => %w[\\Inbox],
              "FLAGS" => %i[Seen],
              "RFC822" =>
                EmailFabricator(
                  message_id: first_message_id,
                  from: first_from,
                  to: group.email_username,
                  cc: second_from,
                  subject: email_subject,
                  body: first_body,
                ),
            },
          ],
        )

      expect { sync_handler.process }.to change { Topic.count }.by(1).and change {
              Post.where(post_type: Post.types[:regular]).count
            }.by(1).and change { IncomingEmail.count }.by(1)

      topic = Topic.last
      expect(topic.title).to eq(email_subject)
      expect(GroupArchivedMessage.where(topic_id: topic.id).exists?).to eq(false)

      post = Post.where(post_type: Post.types[:regular]).last
      expect(post.user.email).to eq(first_from)
      expect(post.raw).to eq(first_body)
      expect(group.imap_uid_validity).to eq(1)
      expect(group.imap_last_uid).to eq(100)

      provider.stubs(:uids).with(to: 100).returns([100])
      provider.stubs(:uids).with(from: 101).returns([200])
      provider
        .stubs(:emails)
        .with([100], %w[UID FLAGS LABELS ENVELOPE], anything)
        .returns([{ "UID" => 100, "LABELS" => %w[\\Inbox], "FLAGS" => %i[Seen] }])
      provider
        .stubs(:emails)
        .with([200], %w[UID FLAGS LABELS RFC822], anything)
        .returns(
          [
            {
              "UID" => 200,
              "LABELS" => %w[\\Inbox],
              "FLAGS" => %i[Recent],
              "RFC822" =>
                EmailFabricator(
                  message_id: SecureRandom.hex,
                  in_reply_to: first_message_id,
                  from: second_from,
                  to: group.email_username,
                  subject: "Re: #{email_subject}",
                  body: second_body,
                ),
            },
          ],
        )

      expect { sync_handler.process }.to not_change { Topic.count }.and change {
              Post.where(post_type: Post.types[:regular]).count
            }.by(1).and change { IncomingEmail.count }.by(1)

      post = Post.where(post_type: Post.types[:regular]).last
      expect(post.user.email).to eq(second_from)
      expect(post.raw).to eq(second_body)
      expect(group.imap_uid_validity).to eq(1)
      expect(group.imap_last_uid).to eq(200)

      provider.stubs(:uids).with(to: 200).returns([100, 200])
      provider.stubs(:uids).with(from: 201).returns([])
      provider
        .stubs(:emails)
        .with([100, 200], %w[UID FLAGS LABELS ENVELOPE], anything)
        .returns(
          [
            { "UID" => 100, "LABELS" => %w[], "FLAGS" => %i[Seen] },
            { "UID" => 200, "LABELS" => %w[], "FLAGS" => %i[Recent] },
          ],
        )

      expect { sync_handler.process }.to not_change { Topic.count }.and not_change {
              Post.where(post_type: Post.types[:regular]).count
            }.and not_change { IncomingEmail.count }

      topic = Topic.last
      expect(topic.title).to eq(email_subject)
      expect(GroupArchivedMessage.where(topic_id: topic.id).exists?).to eq(true)

      expect(Topic.last.posts.where(post_type: Post.types[:regular]).count).to eq(2)
    end

    describe "detecting deleted emails and deleting the topic in discourse" do
      let(:provider) { MockedImapProvider.any_instance }
      before do
        provider.stubs(:open_mailbox).returns(uid_validity: 1)

        provider.stubs(:uids).with.returns([100])
        provider
          .stubs(:emails)
          .with([100], %w[UID FLAGS LABELS RFC822], anything)
          .returns(
            [
              {
                "UID" => 100,
                "LABELS" => %w[\\Inbox],
                "FLAGS" => %i[Seen],
                "RFC822" =>
                  EmailFabricator(
                    message_id: first_message_id,
                    from: first_from,
                    to: group.email_username,
                    cc: second_from,
                    subject: email_subject,
                    body: first_body,
                  ),
              },
            ],
          )
      end

      it "detects previously synced UIDs are missing and deletes the posts if they are in the trash mailbox" do
        sync_handler.process
        incoming_100 = IncomingEmail.find_by(imap_uid: 100)
        provider.stubs(:uids).with.returns([])

        provider.stubs(:uids).with(to: 100).returns([])
        provider.stubs(:uids).with(from: 101).returns([])
        provider.stubs(:find_spam_by_message_ids).returns(stub(spam_emails: []))
        provider.stubs(:find_trashed_by_message_ids).returns(
          stub(
            trashed_emails: [stub(uid: 10, message_id: incoming_100.message_id)],
            trash_uid_validity: 99,
          ),
        )
        sync_handler.process

        incoming_100.reload
        expect(incoming_100.imap_uid_validity).to eq(99)
        expect(incoming_100.imap_uid).to eq(10)
        expect(Post.with_deleted.find(incoming_100.post_id).deleted_at).not_to eq(nil)
        expect(Topic.with_deleted.find(incoming_100.topic_id).deleted_at).not_to eq(nil)
      end

      it "detects previously synced UIDs are missing and deletes the posts if they are in the spam/junk mailbox" do
        sync_handler.process
        incoming_100 = IncomingEmail.find_by(imap_uid: 100)
        provider.stubs(:uids).with.returns([])

        provider.stubs(:uids).with(to: 100).returns([])
        provider.stubs(:uids).with(from: 101).returns([])
        provider.stubs(:find_trashed_by_message_ids).returns(stub(trashed_emails: []))
        provider.stubs(:find_spam_by_message_ids).returns(
          stub(
            spam_emails: [stub(uid: 10, message_id: incoming_100.message_id)],
            spam_uid_validity: 99,
          ),
        )
        sync_handler.process

        incoming_100.reload
        expect(incoming_100.imap_uid_validity).to eq(99)
        expect(incoming_100.imap_uid).to eq(10)
        expect(Post.with_deleted.find(incoming_100.post_id).deleted_at).not_to eq(nil)
        expect(Topic.with_deleted.find(incoming_100.topic_id).deleted_at).not_to eq(nil)
      end

      it "marks the incoming email as IMAP missing if it cannot be found in spam or trash" do
        sync_handler.process
        incoming_100 = IncomingEmail.find_by(imap_uid: 100)
        provider.stubs(:uids).with.returns([])

        provider.stubs(:uids).with(to: 100).returns([])
        provider.stubs(:uids).with(from: 101).returns([])
        provider.stubs(:find_trashed_by_message_ids).returns(stub(trashed_emails: []))
        provider.stubs(:find_spam_by_message_ids).returns(stub(spam_emails: []))
        sync_handler.process

        incoming_100.reload
        expect(incoming_100.imap_missing).to eq(true)
      end

      it "detects the topic being deleted on the discourse site and deletes on the IMAP server and
      does not attempt to delete again on discourse site when deleted already by us on the IMAP server" do
        SiteSetting.enable_imap_write = true
        sync_handler.process
        incoming_100 = IncomingEmail.find_by(imap_uid: 100)
        provider.stubs(:uids).with.returns([100])

        provider.stubs(:uids).with(to: 100).returns([100])
        provider.stubs(:uids).with(from: 101).returns([])

        PostDestroyer.new(
          Discourse.system_user,
          incoming_100.post,
          context: "Automated testing",
        ).destroy
        provider
          .stubs(:emails)
          .with([100], %w[UID FLAGS LABELS ENVELOPE], anything)
          .returns(
            [
              {
                "UID" => 100,
                "LABELS" => %w[\\Inbox],
                "FLAGS" => %i[Seen],
                "RFC822" =>
                  EmailFabricator(
                    message_id: first_message_id,
                    from: first_from,
                    to: group.email_username,
                    cc: second_from,
                    subject: email_subject,
                    body: first_body,
                  ),
              },
            ],
          )
        provider
          .stubs(:emails)
          .with(100, %w[FLAGS LABELS])
          .returns([{ "LABELS" => %w[\\Inbox], "FLAGS" => %i[Seen] }])

        provider.expects(:trash).with(100)
        sync_handler.process

        provider.stubs(:uids).with.returns([])

        provider.stubs(:uids).with(to: 100).returns([])
        provider.stubs(:uids).with(from: 101).returns([])
        provider.stubs(:find_spam_by_message_ids).returns(stub(spam_emails: []))
        provider.stubs(:find_trashed_by_message_ids).returns(
          stub(
            trashed_emails: [stub(uid: 10, message_id: incoming_100.message_id)],
            trash_uid_validity: 99,
          ),
        )
        PostDestroyer.expects(:new).never

        sync_handler.process

        incoming_100.reload
        expect(incoming_100.imap_uid_validity).to eq(99)
        expect(incoming_100.imap_uid).to eq(10)
      end
    end

    describe "archiving emails" do
      let(:provider) { MockedImapProvider.any_instance }
      before do
        SiteSetting.enable_imap_write = true
        provider.stubs(:open_mailbox).returns(uid_validity: 1)

        provider.stubs(:uids).with.returns([100])
        provider
          .stubs(:emails)
          .with([100], %w[UID FLAGS LABELS RFC822], anything)
          .returns(
            [
              {
                "UID" => 100,
                "LABELS" => %w[\\Inbox],
                "FLAGS" => %i[Seen],
                "RFC822" =>
                  EmailFabricator(
                    message_id: first_message_id,
                    from: first_from,
                    to: group.email_username,
                    cc: second_from,
                    subject: email_subject,
                    body: first_body,
                  ),
              },
            ],
          )

        sync_handler.process
        @incoming_email = IncomingEmail.find_by(message_id: first_message_id)
        @topic = @incoming_email.topic

        provider.stubs(:uids).with(to: 100).returns([100])
        provider.stubs(:uids).with(from: 101).returns([101])
        provider
          .stubs(:emails)
          .with([100], %w[UID FLAGS LABELS ENVELOPE], anything)
          .returns([{ "UID" => 100, "LABELS" => %w[\\Inbox], "FLAGS" => %i[Seen] }])
        provider.stubs(:emails).with([101], %w[UID FLAGS LABELS RFC822], anything).returns([])
        provider
          .stubs(:emails)
          .with(100, %w[FLAGS LABELS])
          .returns([{ "LABELS" => %w[\\Inbox], "FLAGS" => %i[Seen] }])
      end

      it "archives an email on the IMAP server when archived in discourse" do
        GroupArchivedMessage.archive!(group.id, @topic, skip_imap_sync: false)
        @incoming_email.update(imap_sync: true)

        provider.stubs(:store).with(100, "FLAGS", anything, anything)
        provider.stubs(:store).with(100, "LABELS", ["\\Inbox"], ["seen"])

        provider.expects(:archive).with(100)
        sync_handler.process
      end

      it "does not archive email if not archived in discourse, it unarchives it instead" do
        @incoming_email.update(imap_sync: true)
        provider.stubs(:store).with(100, "FLAGS", anything, anything)
        provider.stubs(:store).with(100, "LABELS", ["\\Inbox"], ["\\Inbox", "seen"])

        provider.expects(:archive).with(100).never
        provider.expects(:unarchive).with(100)
        sync_handler.process
      end
    end
  end

  describe "invalidated previous sync" do
    let(:email_subject) { "Testing email post" }

    let(:first_from) { "john@free.fr" }
    let(:first_message_id) { SecureRandom.hex }
    let(:first_body) { "This is the first message of this exchange." }

    let(:second_from) { "sam@free.fr" }
    let(:second_message_id) { SecureRandom.hex }
    let(:second_body) { "<p>This is an <b>answer</b> to this message.</p>" }

    # TODO: Improve the invalidating flow for mailbox change. This is a destructive
    # action so it should not be done often.
    xit "is updated" do
      provider = MockedImapProvider.any_instance

      provider.stubs(:open_mailbox).returns(uid_validity: 1)
      provider.stubs(:uids).with.returns([100, 200])
      provider
        .stubs(:emails)
        .with([100, 200], %w[UID FLAGS LABELS RFC822], anything)
        .returns(
          [
            {
              "UID" => 100,
              "LABELS" => %w[\\Inbox],
              "FLAGS" => %i[Seen],
              "RFC822" =>
                EmailFabricator(
                  message_id: first_message_id,
                  from: first_from,
                  to: group.email_username,
                  cc: second_from,
                  subject: email_subject,
                  body: first_body,
                ),
            },
            {
              "UID" => 200,
              "LABELS" => %w[\\Inbox],
              "FLAGS" => %i[Recent],
              "RFC822" =>
                EmailFabricator(
                  message_id: second_message_id,
                  in_reply_to: first_message_id,
                  from: second_from,
                  to: group.email_username,
                  subject: "Re: #{email_subject}",
                  body: second_body,
                ),
            },
          ],
        )

      expect { sync_handler.process }.to change { Topic.count }.by(1).and change {
              Post.where(post_type: Post.types[:regular]).count
            }.by(2).and change { IncomingEmail.count }.by(2)

      imap_data = Topic.last.incoming_email.pluck(:imap_uid_validity, :imap_uid, :imap_group_id)
      expect(imap_data).to contain_exactly([1, 100, group.id], [1, 200, group.id])

      provider.stubs(:open_mailbox).returns(uid_validity: 2)
      provider.stubs(:uids).with.returns([111, 222])
      provider
        .stubs(:emails)
        .with([111, 222], %w[UID FLAGS LABELS RFC822], anything)
        .returns(
          [
            {
              "UID" => 111,
              "LABELS" => %w[\\Inbox],
              "FLAGS" => %i[Seen],
              "RFC822" =>
                EmailFabricator(
                  message_id: first_message_id,
                  from: first_from,
                  to: group.email_username,
                  cc: second_from,
                  subject: email_subject,
                  body: first_body,
                ),
            },
            {
              "UID" => 222,
              "LABELS" => %w[\\Inbox],
              "FLAGS" => %i[Recent],
              "RFC822" =>
                EmailFabricator(
                  message_id: second_message_id,
                  in_reply_to: first_message_id,
                  from: second_from,
                  to: group.email_username,
                  subject: "Re: #{email_subject}",
                  body: second_body,
                ),
            },
          ],
        )

      expect { sync_handler.process }.to not_change { Topic.count }.and not_change {
              Post.where(post_type: Post.types[:regular]).count
            }.and not_change { IncomingEmail.count }

      imap_data = Topic.last.incoming_email.pluck(:imap_uid_validity, :imap_uid, :imap_group_id)
      expect(imap_data).to contain_exactly([2, 111, group.id], [2, 222, group.id])
    end
  end
end

# frozen_string_literal: true

require "email/receiver"

RSpec.describe Email::Receiver, "#process!" do
  before { SiteSetting.email_in = true }

  def configure_reply_by_email
    SiteSetting.reply_by_email_address = "reply+%{reply_key}@bar.com"
    SiteSetting.manual_polling_enabled = true
    SiteSetting.reply_by_email_enabled = true
  end

  def process(email_name, opts = {})
    Email::Receiver.new(email(email_name), opts).process!
  end

  fab!(:group) { Fabricate(:group, incoming_email: "team@bar.com|meat@bar.com") }

  it "handles encoded display names" do
    expect { process(:encoded_display_name) }.to change(Topic, :count)

    topic = Topic.last
    expect(topic.title).to eq("I need help")
    expect(topic.private_message?).to eq(true)
    expect(topic.allowed_groups).to include(group)

    user = topic.user
    expect(user.staged).to eq(true)
    expect(user.username).to eq("user1")
    expect(user.name).to eq("Случайная Имя")
  end

  it "handles email with no subject" do
    expect { process(:no_subject) }.to change(Topic, :count)
    expect(Topic.last.title).to eq("This topic needs a title")
  end

  context "with reply_by_email configured" do
    before { configure_reply_by_email }

    it "invites everyone in the chain but emails configured as 'incoming' (via reply, group or category)" do
      expect { process(:cc) }.to change(Topic, :count)

      topic = Topic.last

      emails = topic.allowed_users.joins(:user_emails).pluck(:"user_emails.email")
      expect(emails).to contain_exactly("someone@else.com", "discourse@bar.com", "wat@bar.com")

      expect(topic.topic_users.count).to eq(3)
    end

    it "invites users with a secondary email in the chain" do
      user1 =
        Fabricate(
          :user,
          trust_level: TrustLevel[2],
          user_emails: [
            Fabricate.build(:secondary_email, email: "discourse@bar.com"),
            Fabricate.build(:secondary_email, email: "someone@else.com"),
          ],
          refresh_auto_groups: true,
        )

      user2 =
        Fabricate(
          :user,
          trust_level: TrustLevel[2],
          user_emails: [
            Fabricate.build(:secondary_email, email: "team@bar.com"),
            Fabricate.build(:secondary_email, email: "wat@bar.com"),
          ],
          refresh_auto_groups: true,
        )

      expect { process(:cc) }.to change(Topic, :count)
      expect(Topic.last.allowed_users).to contain_exactly(user1, user2)
    end

    it "cap the number of staged users created per email" do
      SiteSetting.maximum_staged_users_per_email = 1
      expect { process(:cc) }.to change(Topic, :count).by(1).and change(User, :count).by(1)
      expect(Topic.last.ordered_posts[-1].post_type).to eq(Post.types[:moderator_action])
    end

    it "cap the number of staged users existing per email" do
      Fabricate(:user, email: "discourse@bar.com", staged: true) # from
      Fabricate(:user, email: "someone@else.com", staged: true) # to

      SiteSetting.maximum_staged_users_per_email = 1
      expect { process(:cc) }.to change(Topic, :count).and not_change(User, :count)
      expect(Topic.last.ordered_posts[-1].post_type).to eq(Post.types[:moderator_action])
    end

    it "rejects messages with too many recipients" do
      SiteSetting.maximum_recipients_per_new_group_email = 3
      expect { process(:cc) }.to raise_error(Email::Receiver::TooManyRecipientsError)
    end

    it "uses the incoming_email message-id as the new post's outbound_message_id" do
      expect { process(:cc) }.to change(Topic, :count)
      message_id = IncomingEmail.last.message_id
      expect(Topic.last.first_post.outbound_message_id).to eq(message_id)
    end
  end

  describe "reply-to header" do
    before { SiteSetting.block_auto_generated_emails = false }

    it "extracts address and uses it for comparison" do
      expect { process(:reply_to_whitespaces) }.to change(Topic, :count).by(1)
      incoming = IncomingEmail.find_by(message_id: "TXULO4v6YU0TzeL2buFAJNU2MK21c7t4@example.com")
      expect(incoming.from_address).to eq("johndoe@example.com")
      expect(User.last.email).to eq("johndoe@example.com")
    end

    it "handles emails where there is a Reply-To address, using that instead of the from address, if X-Original-From is present" do
      expect { process(:reply_to_different_to_from) }.to change(Topic, :count).by(1)
      incoming = IncomingEmail.find_by(message_id: "3848c3m98r439c348mc349@test.mailinglist.com")
      expect(incoming.from_address).to eq("arthurmorgan@reddeadtest.com")
      expect(User.last.email).to eq("arthurmorgan@reddeadtest.com")
    end

    it "allows for quotes around the display name of the Reply-To address" do
      expect { process(:reply_to_different_to_from_quoted_display_name) }.to change(
        Topic,
        :count,
      ).by(1)
      incoming = IncomingEmail.find_by(message_id: "3848c3m98r439c348mc349@test.mailinglist.com")
      expect(incoming.from_address).to eq("johnmarston@reddeadtest.com")
      expect(User.last.email).to eq("johnmarston@reddeadtest.com")
    end

    it "does not use the reply-to address if an X-Original-From header is not present" do
      expect { process(:reply_to_different_to_from_no_x_original) }.to change(Topic, :count).by(1)
      incoming = IncomingEmail.find_by(message_id: "3848c3m98r439c348mc349@test.mailinglist.com")
      expect(incoming.from_address).to eq("westernsupport@test.mailinglist.com")
      expect(User.last.email).to eq("westernsupport@test.mailinglist.com")
    end

    it "does not use the reply-to address if the X-Original-From header is different from the reply-to address" do
      expect { process(:reply_to_different_to_from_x_original_different) }.to change(
        Topic,
        :count,
      ).by(1)
      incoming = IncomingEmail.find_by(message_id: "3848c3m98r439c348mc349@test.mailinglist.com")
      expect(incoming.from_address).to eq("westernsupport@test.mailinglist.com")
      expect(User.last.email).to eq("westernsupport@test.mailinglist.com")
    end
  end

  describe "when 'find_related_post_with_key' is disabled" do
    before { SiteSetting.find_related_post_with_key = false }

    it "associates email replies using both 'In-Reply-To' and 'References' headers" do
      expect { process(:email_reply_1) }.to change(Topic, :count).by(1) &
        change(Post, :count).by(3) & change(User, :count).by(3)

      topic = Topic.last
      users = User.last(3)
      ordered_posts = topic.ordered_posts
      expect(ordered_posts.size).to eq(3)

      expect(ordered_posts.first.raw).to eq("This is email reply **1**.")

      ordered_posts[1..-1].each do |post|
        expect(post.action_code).to eq("invited_user")
        expect(post.user.email).to eq("one@foo.com")

        expect(users.map(&:username)).to include(post.custom_fields["action_code_who"])
      end

      expect { process(:email_reply_2) }.to change { topic.posts.count }.by(1)
      expect { process(:email_reply_3) }.to change { topic.posts.count }.by(1)
      ordered_posts[1..-1].each(&:trash!)
      expect { process(:email_reply_4) }.to change { topic.posts.count }.by(1)
    end

    describe "replying with various message-id formats using In-Reply-To header" do
      let!(:topic) do
        process(:email_reply_1)
        Topic.last
      end
      let!(:post) { Fabricate(:post, topic: topic) }

      def process_mail_with_message_id(message_id)
        mail_string = <<~EMAIL
          Return-Path: <two@foo.com>
          From: Two <two@foo.com>
          To: one@foo.com
          Subject: RE: Testing email threading
          Date: Fri, 15 Jan 2016 00:12:43 +0100
          Message-ID: <44@foo.bar.mail>
          In-Reply-To: <#{message_id}>
          Mime-Version: 1.0
          Content-Type: text/plain
          Content-Transfer-Encoding: 7bit

          This is email reply testing with Message-ID formats.
          EMAIL
        Email::Receiver.new(mail_string).process!
      end

      it "posts a reply using a message-id in the format discourse/post/POST_ID@HOST" do
        expect {
          process_mail_with_message_id("discourse/post/#{post.id}@test.localhost")
        }.to change { Post.count }.by(1)
        expect(topic.reload.posts.last.raw).to include(
          "This is email reply testing with Message-ID formats",
        )
      end
    end
  end

  it "supports any kind of attachments when 'allow_all_attachments_for_group_messages' is enabled" do
    SiteSetting.allow_all_attachments_for_group_messages = true
    expect { process(:attached_rb_file) }.to change(Topic, :count)

    post = Topic.last.first_post
    upload = post.uploads.first

    expect(post.raw).to include UploadMarkdown.new(upload).to_markdown
  end

  it "reenables user's PM email notifications when user emails new topic to group" do
    user = Fabricate(:user, email: "existing@bar.com")
    user.user_option.update_columns(email_messages_level: UserOption.email_level_types[:never])
    expect { process(:group_existing_user) }.to change(Topic, :count)
    user.reload
    expect(user.user_option.email_messages_level).to eq(UserOption.email_level_types[:always])
  end

  context "with forwarded emails behaviour set to create replies" do
    before do
      Fabricate(:group, incoming_email: "some_group@bar.com")
      SiteSetting.forwarded_emails_behaviour = "create_replies"
    end

    it "handles forwarded emails" do
      expect { process(:forwarded_email_1) }.to change(Topic, :count)

      forwarded_post, last_post = *Post.last(2)

      expect(forwarded_post.user.email).to eq("some@one.com")
      expect(last_post.user.email).to eq("ba@bar.com")

      expect(forwarded_post.raw).to match(/XoXo/)
      expect(last_post.raw).to match(/can you have a look at this email below/)

      expect(last_post.post_type).to eq(Post.types[:regular])
    end

    it "handles weirdly forwarded emails" do
      group.add(Fabricate(:user, email: "ba@bar.com"))
      group.save

      SiteSetting.forwarded_emails_behaviour = "create_replies"
      expect { process(:forwarded_email_2) }.to change(Topic, :count)

      forwarded_post, last_post = *Post.last(2)

      expect(forwarded_post.user.email).to eq("some@one.com")
      expect(last_post.user.email).to eq("ba@bar.com")

      expect(forwarded_post.raw).to match(/XoXo/)
      expect(last_post.raw).to match(/can you have a look at this email below/)

      expect(last_post.post_type).to eq(Post.types[:whisper])
    end

    # Who thought this was a good idea?!
    it "doesn't blow up with localized email headers" do
      expect { process(:forwarded_email_3) }.to change(Topic, :count)
    end

    it "adds a small action post to explain who forwarded the email when the sender didn't write anything" do
      expect { process(:forwarded_email_4) }.to change(Topic, :count)

      forwarded_post, last_post = *Post.last(2)

      expect(forwarded_post.user.email).to eq("some@one.com")
      expect(forwarded_post.raw).to match(/XoXo/)

      expect(last_post.user.email).to eq("ba@bar.com")
      expect(last_post.post_type).to eq(Post.types[:small_action])
      expect(last_post.action_code).to eq("forwarded")
    end
  end

  context "with forwarded emails behaviour set to quote" do
    before { SiteSetting.forwarded_emails_behaviour = "quote" }

    include_examples "creates topic with forwarded message as quote",
                     :group,
                     "team@bar.com|meat@bar.com"
  end

  context "when a reply is sent to a group's email_username" do
    let!(:topic) do
      group.update(email_username: "team@somesmtpaddress.com")
      process(:email_reply_1)
      Topic.last
    end

    it "does not invite the group email_username as a staged user" do
      process(:email_reply_to_group_email_username)
      expect(User.find_by_email("team@somesmtpaddress.com")).to eq(nil)
    end

    it "creates the reply when the sender and referenced message id are known" do
      expect { process(:email_reply_to_group_email_username) }.to change { topic.posts.count }.by(
        1,
      ).and not_change { Topic.count }
    end
  end

  context "when a group forwards an email to its inbox" do
    before do
      group.update!(
        email_username: "team@somesmtpaddress.com",
        incoming_email: "team@somesmtpaddress.com|support+team@bar.com",
        smtp_server: "smtp.test.com",
        smtp_port: 587,
        smtp_ssl_mode: Group.smtp_ssl_modes[:starttls],
        smtp_enabled: true,
      )
    end

    it "does not use the team's address as the from_address; it uses the original sender address" do
      process(:forwarded_by_group_to_inbox)
      topic = Topic.last
      expect(topic.incoming_email.first.to_addresses).to include("support+team@bar.com")
      expect(topic.incoming_email.first.from_address).to eq("fred@bedrock.com")
    end

    context "with forwarded emails behaviour set to create replies" do
      before { SiteSetting.forwarded_emails_behaviour = "create_replies" }

      it "does not use the team's address as the from_address; it uses the original sender address" do
        process(:forwarded_by_group_to_inbox)
        topic = Topic.last
        expect(topic.incoming_email.first.to_addresses).to include("support+team@bar.com")
        expect(topic.incoming_email.first.from_address).to eq("fred@bedrock.com")
      end

      it "does not say the email was forwarded by the original sender, it says the email is forwarded by the group" do
        expect { process(:forwarded_by_group_to_inbox) }.to change {
          User.where(staged: true).count
        }.by(4)
        topic = Topic.last
        forwarded_small_post = topic.ordered_posts.last
        expect(forwarded_small_post.action_code).to eq("forwarded")
        expect(forwarded_small_post.user).to eq(User.find_by_email("team@somesmtpaddress.com"))
      end

      it "keeps track of the cc addresses of the forwarded email and creates staged users for them" do
        expect { process(:forwarded_by_group_to_inbox) }.to change {
          User.where(staged: true).count
        }.by(4)
        topic = Topic.last
        cc_user1 = User.find_by_email("terry@ccland.com")
        cc_user2 = User.find_by_email("don@ccland.com")
        fred_user = User.find_by_email("fred@bedrock.com")
        team_user = User.find_by_email("team@somesmtpaddress.com")
        expect(topic.incoming_email.first.cc_addresses).to eq("terry@ccland.com;don@ccland.com")
        expect(topic.topic_allowed_users.pluck(:user_id)).to match_array(
          [fred_user.id, team_user.id, cc_user1.id, cc_user2.id],
        )
      end

      it "keeps track of the cc addresses of the final forwarded email as well" do
        expect { process(:forwarded_by_group_to_inbox_double_cc) }.to change {
          User.where(staged: true).count
        }.by(5)
        topic = Topic.last
        cc_user1 = User.find_by_email("terry@ccland.com")
        cc_user2 = User.find_by_email("don@ccland.com")
        fred_user = User.find_by_email("fred@bedrock.com")
        team_user = User.find_by_email("team@somesmtpaddress.com")
        someother_user = User.find_by_email("someotherparty@test.com")
        expect(topic.incoming_email.first.cc_addresses).to eq(
          "someotherparty@test.com;terry@ccland.com;don@ccland.com",
        )
        expect(topic.topic_allowed_users.pluck(:user_id)).to match_array(
          [fred_user.id, team_user.id, someother_user.id, cc_user1.id, cc_user2.id],
        )
      end

      context "when staged user for the team email already exists" do
        let!(:staged_team_user) do
          User.create!(
            email: "team@somesmtpaddress.com",
            username: UserNameSuggester.suggest("team@somesmtpaddress.com"),
            name: "team teamson",
            staged: true,
          )
        end

        it "uses that and does not create another staged user" do
          expect { process(:forwarded_by_group_to_inbox) }.to change {
            User.where(staged: true).count
          }.by(3)
          topic = Topic.last
          forwarded_small_post = topic.ordered_posts.last
          expect(forwarded_small_post.action_code).to eq("forwarded")
          expect(forwarded_small_post.user).to eq(staged_team_user)
        end
      end
    end
  end

  context "when emailing a group by email_username and following reply flow" do
    let!(:original_inbound_email_topic) do
      group.update!(
        email_username: "team@somesmtpaddress.com",
        incoming_email: "team@somesmtpaddress.com|suppor+team@bar.com",
        smtp_server: "smtp.test.com",
        smtp_port: 587,
        smtp_ssl_mode: Group.smtp_ssl_modes[:starttls],
        smtp_enabled: true,
      )
      process(:email_to_group_email_username_1)
      Topic.last
    end

    fab!(:user_in_group) do
      u = Fabricate(:user)
      Fabricate(:group_user, user: u, group: group)
      u
    end

    before do
      NotificationEmailer.enable
      SiteSetting.disallow_reply_by_email_after_days = 10_000
      Jobs.run_immediately!
    end

    def reply_as_group_user
      group_post =
        PostCreator.create(
          user_in_group,
          raw: "Thanks for your request. Please try to restart.",
          topic_id: original_inbound_email_topic.id,
        )
      email_log = EmailLog.last
      [email_log, group_post]
    end

    it "the inbound processed email creates an incoming email and topic record correctly, and adds the group to the topic" do
      incoming = IncomingEmail.find_by(topic: original_inbound_email_topic)
      user = User.find_by_email("two@foo.com")
      expect(original_inbound_email_topic.topic_allowed_users.first.user_id).to eq(user.id)
      expect(original_inbound_email_topic.topic_allowed_groups.first.group_id).to eq(group.id)
      expect(incoming.to_addresses).to eq("team@somesmtpaddress.com")
      expect(incoming.from_address).to eq("two@foo.com")
      expect(incoming.message_id).to eq("u4w8c9r4y984yh98r3h69873@foo.bar.mail")
    end

    it "creates an EmailLog when someone from the group replies, and does not create an IncomingEmail record for the reply" do
      email_log, group_post = reply_as_group_user
      expect(email_log.message_id).to eq("discourse/post/#{group_post.id}@test.localhost")
      expect(email_log.to_address).to eq("two@foo.com")
      expect(email_log.email_type).to eq("user_private_message")
      expect(email_log.post_id).to eq(group_post.id)
      expect(IncomingEmail.exists?(post_id: group_post.id)).to eq(false)
    end

    it "processes a reply from the OP user to the group SMTP username, linking the reply_to_post_number correctly by matching in_reply_to to the email log" do
      email_log, group_post = reply_as_group_user

      reply_email = email(:email_to_group_email_username_2)
      reply_email.gsub!("MESSAGE_ID_REPLY_TO", email_log.message_id)
      expect { Email::Receiver.new(reply_email).process! }.to not_change {
        Topic.count
      }.and change { Post.count }.by(1)

      reply_post = Post.last
      expect(reply_post.reply_to_user).to eq(user_in_group)
      expect(reply_post.reply_to_post_number).to eq(group_post.post_number)
    end

    it "handles multiple message IDs in the in_reply_to header by only using the first one" do
      email_log, group_post = reply_as_group_user

      reply_email = email(:email_to_group_email_username_3)
      reply_email.gsub!(
        "MESSAGE_ID_REPLY_TO",
        "<#{email_log.message_id}> <test/message/id@discourse.com>",
      )
      expect { Email::Receiver.new(reply_email).process! }.to not_change {
        Topic.count
      }.and change { Post.count }.by(1)

      reply_post = Post.last
      expect(reply_post.reply_to_user).to eq(user_in_group)
      expect(reply_post.reply_to_post_number).to eq(group_post.post_number)
    end

    it "processes the reply from the user as a brand new topic if they have replied from a different address (e.g. auto forward) and allow_unknown_sender_topic_replies is disabled" do
      email_log, _group_post = reply_as_group_user

      reply_email = email(:email_to_group_email_username_2_as_unknown_sender)
      reply_email.gsub!("MESSAGE_ID_REPLY_TO", email_log.message_id)
      expect { Email::Receiver.new(reply_email).process! }.to change { Topic.count }.by(
        1,
      ).and change { Post.count }.by(1)

      reply_post = Post.last
      expect(reply_post.topic_id).not_to eq(original_inbound_email_topic.id)
    end

    it "processes the reply from the user as a reply if they have replied from a different address (e.g. auto forward) and allow_unknown_sender_topic_replies is enabled" do
      group.update!(allow_unknown_sender_topic_replies: true)
      email_log, _group_post = reply_as_group_user

      reply_email = email(:email_to_group_email_username_2_as_unknown_sender)
      reply_email.gsub!("MESSAGE_ID_REPLY_TO", email_log.message_id)
      expect { Email::Receiver.new(reply_email).process! }.to not_change {
        Topic.count
      }.and change { Post.count }.by(1)

      reply_post = Post.last
      expect(reply_post.topic_id).to eq(original_inbound_email_topic.id)
    end

    it "creates a new topic with a reference back to the original if replying to a too old topic" do
      SiteSetting.disallow_reply_by_email_after_days = 2
      email_log, group_post = reply_as_group_user

      group_post.update(created_at: 10.days.ago)
      group_post.topic.update(created_at: 10.days.ago)

      reply_email = email(:email_to_group_email_username_2)
      reply_email.gsub!("MESSAGE_ID_REPLY_TO", email_log.message_id)
      expect { Email::Receiver.new(reply_email).process! }.to change { Topic.count }.by(
        1,
      ).and change { Post.count }.by(1)

      reply_post = Post.last
      new_topic = Topic.last

      expect(reply_post.topic).to eq(new_topic)
      expect(reply_post.raw).to include(
        I18n.t(
          "emails.incoming.continuing_old_discussion",
          url: group_post.topic.url,
          title: group_post.topic.title,
          count: SiteSetting.disallow_reply_by_email_after_days,
        ),
      )
    end
  end

  context "when message sent to a group has no key and find_related_post_with_key is enabled" do
    let!(:topic) do
      process(:email_reply_1)
      Topic.last
    end

    it "creates a reply when the sender and referenced message id are known" do
      expect { process(:email_reply_2) }.to change { topic.posts.count }.by(1).and not_change {
              Topic.count
            }
    end

    it "creates a new topic when the sender is not known and the group does not allow unknown senders to reply to topics" do
      IncomingEmail.where(message_id: "34@foo.bar.mail").update(cc_addresses: "three@foo.com")
      group.update(allow_unknown_sender_topic_replies: false)
      expect { process(:email_reply_2) }.to not_change { topic.posts.count }.and change {
              Topic.count
            }.by(1)
    end

    it "creates a new topic when the referenced message id is not known" do
      IncomingEmail.where(message_id: "34@foo.bar.mail").update(message_id: "99@foo.bar.mail")
      expect { process(:email_reply_2) }.to not_change { topic.posts.count }.and change {
              Topic.count
            }.by(1)
    end

    it "includes the sender on the topic when the message id is known, the sender is not known, and the group allows unknown senders to reply to topics" do
      IncomingEmail.where(message_id: "34@foo.bar.mail").update(cc_addresses: "three@foo.com")
      group.update(allow_unknown_sender_topic_replies: true)
      expect { process(:email_reply_2) }.to change { topic.posts.count }.by(1).and not_change {
              Topic.count
            }
    end

    context "when the sender is not in the topic allowed users" do
      before do
        user = User.find_by_email("two@foo.com")
        topic.topic_allowed_users.find_by(user: user).destroy
      end

      it "adds them to the topic at the same time" do
        IncomingEmail.where(message_id: "34@foo.bar.mail").update(cc_addresses: "three@foo.com")
        group.update(allow_unknown_sender_topic_replies: true)
        expect { process(:email_reply_2) }.to change { topic.posts.count }.by(1).and not_change {
                Topic.count
              }
      end
    end
  end
end

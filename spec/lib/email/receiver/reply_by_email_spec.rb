# frozen_string_literal: true

require "email/receiver"

RSpec.describe Email::Receiver, "#process!" do
  before do
    SiteSetting.email_in = true
    configure_reply_by_email
  end

  def configure_reply_by_email
    SiteSetting.reply_by_email_address = "reply+%{reply_key}@bar.com"
    SiteSetting.manual_polling_enabled = true
    SiteSetting.reply_by_email_enabled = true
  end

  def process(email_name, opts = {})
    Email::Receiver.new(email(email_name), opts).process!
  end

  it "raises an OldDestinationError when notification is too old" do
    SiteSetting.disallow_reply_by_email_after_days = 2

    topic = Fabricate(:topic)
    post = Fabricate(:post, topic: topic)
    Fabricate(:user, email: "discourse@bar.com")

    mail = email(:old_destination).gsub(":post_id", post.id.to_s)
    expect { Email::Receiver.new(mail).process! }.to raise_error(
      Email::Receiver::BadDestinationAddress,
    )

    IncomingEmail.destroy_all
    post.update!(created_at: 3.days.ago)

    expect { Email::Receiver.new(mail).process! }.to raise_error(
      Email::Receiver::OldDestinationError,
    )
    expect(IncomingEmail.last.error).to eq("Email::Receiver::OldDestinationError")

    SiteSetting.disallow_reply_by_email_after_days = 0
    IncomingEmail.destroy_all

    expect { Email::Receiver.new(mail).process! }.to raise_error(
      Email::Receiver::BadDestinationAddress,
    )
  end

  it "doesn't raise an InactiveUserError when the sender is staged" do
    user = Fabricate(:user, email: "staged@bar.com", active: false, staged: true)
    post = Fabricate(:post)

    Fabricate(
      :post_reply_key,
      user: user,
      post: post,
      reply_key: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    )

    expect { process(:staged_sender) }.not_to raise_error
  end

  it "raises a FromReplyByAddressError when the email is from the reply by email address" do
    expect { process(:from_reply_by_email_address) }.to raise_error(
      Email::Receiver::FromReplyByAddressError,
    )
  end

    # bounce handling depends on reply_by_email being enabled
  describe "bounces" do
    it "raises a BouncerEmailError" do
      expect { process(:bounced_email) }.to raise_error(Email::Receiver::BouncedEmailError)
      expect(IncomingEmail.last.is_bounce).to eq(true)

      expect { process(:bounced_email_multiple_status_codes) }.to raise_error(
        Email::Receiver::BouncedEmailError,
      )
      expect(IncomingEmail.last.is_bounce).to eq(true)
    end

    describe "creating whisper post in PMs for staged users" do
      let(:email_address) { "linux-admin@b-s-c.co.jp" }
      fab!(:user1) { Fabricate(:user, refresh_auto_groups: true) }
      let(:user2) { Fabricate(:staged, email: email_address) }
      let(:topic) do
        Fabricate(
          :topic,
          archetype: "private_message",
          category_id: nil,
          user: user1,
          allowed_users: [user1, user2],
        )
      end
      let(:post) { create_post(topic: topic, user: user1) }

      before do
        SiteSetting.enable_staged_users = true
        SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
      end

      it "when bounce without verp" do
        Fabricate(
          :post_reply_key,
          reply_key: "4f97315cc828096c9cb34c6f1a0d6fe8",
          user: user2,
          post: post,
        )

        expect { process(:bounced_email) }.to raise_error(Email::Receiver::BouncedEmailError)
        post = Post.last
        expect(post.whisper?).to eq(true)
        expect(post.raw).to eq(
          I18n.t(
            "system_messages.email_bounced",
            email: email_address,
            raw: "Your email bounced",
          ).strip,
        )
        expect(IncomingEmail.last.is_bounce).to eq(true)
      end

      context "when bounce with verp" do
        let(:bounce_key) { "14b08c855160d67f2e0c2f8ef36e251e" }

        before do
          Fabricate(:post_reply_key, reply_key: bounce_key, user: user2, post: post)
          Fabricate(
            :email_log,
            to_address: email_address,
            user: user2,
            bounce_key: bounce_key,
            post: post,
          )
          SiteSetting.reply_by_email_address = "foo+%{reply_key}@discourse.org"
        end



        it "creates a post with the bounce error" do
          expect { process(:hard_bounce_via_verp) }.to raise_error(
            Email::Receiver::BouncedEmailError,
          )
          post = Post.last
          expect(post.whisper?).to eq(true)
          expect(post.raw).to eq(
            I18n.t(
              "system_messages.email_bounced",
              email: email_address,
              raw: "Your email bounced",
            ).strip,
          )
          expect(IncomingEmail.last.is_bounce).to eq(true)
        end

        it "updates the email log with the bounce error message" do
          expect { process(:hard_bounce_via_verp) }.to raise_error(
            Email::Receiver::BouncedEmailError,
          )
          email_log = EmailLog.find_by(bounce_key: bounce_key)
          expect(email_log.bounced).to eq(true)
          expect(email_log.bounce_error_code).to eq("5.1.1")
        end
      end
    end
  end

  describe "reply" do
    let(:reply_key) { "4f97315cc828096c9cb34c6f1a0d6fe8" }
    fab!(:category)
    fab!(:user) { Fabricate(:user, email: "discourse@bar.com", refresh_auto_groups: true) }
    fab!(:topic) { create_topic(category: category, user: user) }
    fab!(:post) { create_post(topic: topic) }

    before do
      Fabricate(:post_reply_key, reply_key: reply_key, user: user, post: post)
    end

    let :topic_user do
      TopicUser.find_by(topic_id: topic.id, user_id: user.id)
    end

    it "accepts reply from secondary email address" do
      Fabricate(:secondary_email, email: "someone_else@bar.com", user: user)

      expect { process(:reply_user_not_matching) }.to change { topic.posts.count }

      post = Post.last

      expect(post.raw).to eq("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")

      expect(post.user).to eq(user)
    end

    it "uses MD5 of 'mail_string' there is no message_id" do
      mail_string = email(:missing_message_id)
      expect { Email::Receiver.new(mail_string).process! }.to change { IncomingEmail.count }
      expect(IncomingEmail.last.message_id).to eq(Digest::MD5.hexdigest(mail_string))
    end

    it "raises a ReplyUserNotMatchingError when the email address isn't matching the one we sent the notification to" do
      Fabricate(:user, email: "someone_else@bar.com")
      expect { process(:reply_user_not_matching) }.to raise_error(
        Email::Receiver::ReplyUserNotMatchingError,
      )
    end

    it "raises a ReplyNotAllowedError when user without permissions is replying" do
      Fabricate(:user, email: "bob@bar.com")
      category.set_permissions(admins: :full)
      category.save
      expect { process(:reply_user_not_matching_but_known) }.to raise_error(
        Email::Receiver::ReplyNotAllowedError,
      )
    end

    it "creates a reply post" do
      expect { process(:reply_user_matching) }.to change { topic.posts.count }
    end

    it "works when sent to an alternative reply address" do
      SiteSetting.alternative_reply_by_email_addresses = "alt+%{reply_key}@bar.com"
      expect { process(:reply_user_matching_alternativereplyaddr) }.to change {
        topic.posts.count
      }
    end

    it "raises a TopicNotFoundError when the topic was deleted" do
      topic.update_columns(deleted_at: 1.day.ago)
      expect { process(:reply_user_matching) }.to raise_error(Email::Receiver::TopicNotFoundError)
    end

    context "with a closed topic" do
      before { topic.update_columns(closed: true) }

      it "raises a TopicClosedError when the topic was closed" do
        expect { process(:reply_user_matching) }.to raise_error(Email::Receiver::TopicClosedError)
      end

      it "Can watch topics via the watch command" do
        # TODO support other locales as well, the tricky thing is that these string live in
        # client.yml not on server yml so it is a bit tricky to find

        topic.update_columns(closed: true)
        process(:watch)
        expect(topic_user.notification_level).to eq(NotificationLevels.topic_levels[:watching])
      end

      it "Can mute topics via the mute command" do
        process(:mute)
        expect(topic_user.notification_level).to eq(NotificationLevels.topic_levels[:muted])
      end

      it "can track a topic via the track command" do
        process(:track)
        expect(topic_user.notification_level).to eq(NotificationLevels.topic_levels[:tracking])
      end
    end

    it "raises an InvalidPost when there was an error while creating the post" do
      expect { process(:too_small) }.to raise_error(Email::Receiver::TooShortPost)
    end

    it "raises an InvalidPost when there are too may mentions" do
      SiteSetting.max_mentions_per_post = 1
      Fabricate(:user, username: "user1")
      Fabricate(:user, username: "user2")
      expect { process(:too_many_mentions) }.to raise_error(Email::Receiver::InvalidPost)
    end

    it "raises an InvalidPostAction when they aren't allowed to like a post" do
      topic.update_columns(archived: true)
      expect { process(:like) }.to raise_error(Email::Receiver::InvalidPostAction)
    end

    it "creates a new reply post" do
      handler_calls = 0
      handler = proc { |_| handler_calls += 1 }

      DiscourseEvent.on(:topic_created, &handler)

      expect { process(:text_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This is a text reply :)\n\nEmail parsing should not break because of a UTF-8 character: ’",
      )
      expect(topic.posts.last.via_email).to eq(true)
      expect(topic.posts.last.cooked).not_to match(/<br/)

      expect { process(:html_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is a **HTML** reply ;)")

      DiscourseEvent.off(:topic_created, &handler)
      expect(handler_calls).to eq(0)
    end

    it "stores the created_via source against the incoming email" do
      process(:text_reply, source: :handle_mail)
      expect(IncomingEmail.last.created_via).to eq(IncomingEmail.created_via_types[:handle_mail])
      process(:text_and_html_reply, source: :pop3_poll)
      expect(IncomingEmail.last.created_via).to eq(IncomingEmail.created_via_types[:pop3_poll])
    end

    it "stores the message_id of the incoming email against the post as outbound_message_id" do
      expect { process(:text_reply, source: :handle_mail) }.to change(Post, :count)
      message_id = IncomingEmail.last.message_id
      expect(Post.last.outbound_message_id).to eq(message_id)
    end

    it "automatically elides gmail quotes" do
      SiteSetting.always_show_trimmed_content = true
      expect { process(:gmail_html_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq <<~MD.strip
        This is a **GMAIL** reply ;)

        <details class='elided'>
        <summary title='Show trimmed content'>&#183;&#183;&#183;</summary>

        This is the *elided* part!

        </details>
      MD
    end

    it "correctly extracts body from exchange emails" do
      SiteSetting.always_show_trimmed_content = true
      expect { process(:exchange_html_body) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is the **body** of the email.")
    end

    it "correctly extracts reply from exchange emails" do
      SiteSetting.always_show_trimmed_content = true
      expect { process(:exchange_html_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is the **body !!** of the email.")
    end

    it "correctly extracts body & reply from exchange emails" do
      SiteSetting.always_show_trimmed_content = true
      expect { process(:exchange_html_body_and_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq <<~MD.strip
        This is the **body** of the email.

        <details class='elided'>
        <summary title='Show trimmed content'>&#183;&#183;&#183;</summary>

        This is the *reply*!

        </details>
      MD
    end

    it "keeps the lists and only elides the signature from word emails" do
      expect { process(:word_html_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq <<~MD.strip
        This is the **body** of the email.

        - a bullet
        - another bullet

        And these are the steps to follow:

        1. a first step
        1. a second step

        That's all folks!
      MD
    end

    it "doesn't process email with same message-id more than once" do
      expect do
        process(:text_reply)
        process(:text_reply)
      end.to change { topic.posts.count }.by(1)
    end

    it "handles different encodings correctly" do
      expect { process(:hebrew_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("שלום! מה שלומך היום?")

      expect { process(:chinese_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("您好！ 你今天好吗？")

      expect { process(:reply_with_weird_encoding) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is a reply with a weird encoding.")

      expect { process(:reply_with_8bit_encoding) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("hab vergessen kritische zeichen einzufügen:\näöüÄÖÜß")
    end

    it "prefers text over html when site setting is disabled" do
      SiteSetting.incoming_email_prefer_html = false
      expect { process(:text_and_html_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is the *text* part.")
    end

    it "prefers html over text when site setting is enabled" do
      SiteSetting.incoming_email_prefer_html = true
      expect { process(:text_and_html_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is the **html** part.")
    end

    it "uses text when prefer_html site setting is enabled but no html is available" do
      SiteSetting.incoming_email_prefer_html = true
      expect { process(:text_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This is a text reply :)\n\nEmail parsing should not break because of a UTF-8 character: ’",
      )
    end

    it "removes the 'on <date>, <contact> wrote' quoting line" do
      expect { process(:on_date_contact_wrote) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is the actual reply.")
    end

    it "removes the 'Previous Replies' marker" do
      expect { process(:previous_replies) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This will not include the previous discussion that is present in this email.",
      )
    end

    it "removes the translated 'Previous Replies' marker" do
      expect { process(:previous_replies_de) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This will not include the previous discussion that is present in this email.",
      )
    end

    it "removes the 'type reply above' marker" do
      expect { process(:reply_above) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This will not include the previous discussion that is present in this email.",
      )
    end

    it "removes the translated 'type reply above' marker" do
      expect { process(:reply_above_de) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This will not include the previous discussion that is present in this email.",
      )
    end

    it "handles multiple paragraphs" do
      expect { process(:paragraphs) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "Do you like liquorice?\n\nI really like them. One could even say that I am *addicted* to liquorice. And if\nyou can mix it up with some anise, then I'm in heaven ;)",
      )
    end

    it "raises a NoSenderDetectedError when the From header can't be parsed" do
      expect { process(:invalid_from_1) }.to raise_error(Email::Receiver::NoSenderDetectedError)
    end

    it "raises a NoSenderDetectedError when the From header doesn't contain an email address" do
      expect { process(:invalid_from_2) }.to raise_error(Email::Receiver::NoSenderDetectedError)
    end

    it "doesn't raise an AutoGeneratedEmailError due to an X-Auto-Response-Suppress header" do
      expect { process(:quirks_exchange_xars) }.to change { topic.posts.count }
    end

    it "doesn't raise an AutoGeneratedEmailError when the mail is auto generated but is allowlisted" do
      SiteSetting.auto_generated_allowlist = "foo@bar.com|discourse@bar.com"
      expect { process(:auto_generated_allowlisted) }.to change { topic.posts.count }
    end

    it "doesn't raise an AutoGeneratedEmailError when block_auto_generated_emails is disabled" do
      SiteSetting.block_auto_generated_emails = false
      expect { process(:auto_generated_unblocked) }.to change { topic.posts.count }
    end

    it "allows staged users to reply to a restricted category" do
      user.update_columns(staged: true)

      category.email_in = "category@bar.com"
      category.email_in_allow_strangers = true
      category.set_permissions(Group[:trust_level_4] => :full)
      category.save!

      expect { process(:staged_reply_restricted) }.to change { topic.posts.count }
    end

    it "posts a reply to the topic when the post was deleted" do
      post.update_columns(deleted_at: 1.day.ago)
      expect { process(:reply_user_matching) }.to change { topic.posts.count }
      expect(topic.ordered_posts.last.reply_to_post_number).to be_nil
    end

    describe "Unsubscribing via email" do
      let(:last_email) { ActionMailer::Base.deliveries.last }

      describe "unsubscribe_subject.eml" do
        it "sends an email asking the user to confirm the unsubscription" do
          expect { process("unsubscribe_subject") }.to change {
            ActionMailer::Base.deliveries.count
          }.by(1)
          expect(last_email.to.length).to eq 1
          expect(last_email.from.length).to eq 1
          expect(last_email.from).to include "noreply@#{Discourse.current_hostname}"
          expect(last_email.to).to include "discourse@bar.com"
          expect(last_email.subject).to eq I18n.t(:"unsubscribe_mailer.subject_template").gsub(
               "%{site_title}",
               SiteSetting.title,
             )
        end

        it "does nothing unless unsubscribe_via_email is turned on" do
          SiteSetting.unsubscribe_via_email = false
          before_deliveries = ActionMailer::Base.deliveries.count
          expect { process("unsubscribe_subject") }.to raise_error {
            Email::Receiver::BadDestinationAddress
          }
          expect(before_deliveries).to eq ActionMailer::Base.deliveries.count
        end
      end

      describe "unsubscribe_body.eml" do
        it "sends an email asking the user to confirm the unsubscription" do
          expect { process("unsubscribe_body") }.to change {
            ActionMailer::Base.deliveries.count
          }.by(1)
          expect(last_email.to.length).to eq 1
          expect(last_email.from.length).to eq 1
          expect(last_email.from).to include "noreply@#{Discourse.current_hostname}"
          expect(last_email.to).to include "discourse@bar.com"
          expect(last_email.subject).to eq I18n.t(:"unsubscribe_mailer.subject_template").gsub(
               "%{site_title}",
               SiteSetting.title,
             )
        end

        it "does nothing unless unsubscribe_via_email is turned on" do
          SiteSetting.unsubscribe_via_email = false
          before_deliveries = ActionMailer::Base.deliveries.count
          expect { process("unsubscribe_body") }.to raise_error { Email::Receiver::InvalidPost }
          expect(before_deliveries).to eq ActionMailer::Base.deliveries.count
        end
      end

      it "raises an UnsubscribeNotAllowed and does not send an unsubscribe email" do
        before_deliveries = ActionMailer::Base.deliveries.count
        expect { process(:unsubscribe_new_user) }.to raise_error {
          Email::Receiver::UnsubscribeNotAllowed
        }
        expect(before_deliveries).to eq ActionMailer::Base.deliveries.count
      end
    end

    it "handles inline reply" do
      expect { process(:inline_reply) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("And this is *my* reply :+1:")
    end

    it "retrieves the first part of multiple replies" do
      expect { process(:inline_mixed_replies) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "> WAT <https://bar.com/users/wat> November 28\n>\n> This is the previous post.\n\nAnd this is *my* reply :+1:\n\n> This is another post.\n\nAnd this is **another** reply.",
      )
    end

    it "strips mobile/webmail signatures" do
      expect { process(:iphone_signature) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is not the signature you're looking for.")
    end

    it "strips 'original message' context" do
      expect { process(:original_message) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is a reply :)")
    end

    it "add the 'elided' part of the original message only for private messages" do
      topic.update_columns(category_id: nil, archetype: Archetype.private_message)
      topic.allowed_users << user
      topic.save

      expect { process(:original_message) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This is a reply :)\n\n<details class='elided'>\n<summary title='Show trimmed content'>&#183;&#183;&#183;</summary>\n\n---Original Message---\nThis part should not be included\n\n</details>",
      )
    end

    it "doesn't include the 'elided' part of the original message when always_show_trimmed_content is disabled" do
      SiteSetting.always_show_trimmed_content = false
      expect { process(:original_message) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq("This is a reply :)")
    end

    it "adds the 'elided' part of the original message for public replies when always_show_trimmed_content is enabled" do
      SiteSetting.always_show_trimmed_content = true
      expect { process(:original_message) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This is a reply :)\n\n<details class='elided'>\n<summary title='Show trimmed content'>&#183;&#183;&#183;</summary>\n\n---Original Message---\nThis part should not be included\n\n</details>",
      )
    end

    it "doesn't trim the message when trim_incoming_emails is disabled" do
      SiteSetting.trim_incoming_emails = false
      expect { process(:original_message) }.to change { topic.posts.count }
      expect(topic.posts.last.raw).to eq(
        "This is a reply :)\n\n---Original Message---\nThis part should not be included",
      )
    end

    it "supports attached images in TEXT part" do
      SiteSetting.incoming_email_prefer_html = false

      expect { process(:no_body_with_image) }.to change { topic.posts.count }

      post = topic.posts.last
      upload = post.uploads.first

      expect(post.raw).to include UploadMarkdown.new(upload).to_markdown

      expect { process(:inline_image) }.to change { topic.posts.count }

      post = topic.posts.last
      upload = post.uploads.first

      expect(post.raw).to include UploadMarkdown.new(upload).to_markdown
    end

    it "supports attached images in HTML part" do
      SiteSetting.incoming_email_prefer_html = true

      expect { process(:inline_image) }.to change { topic.posts.count }

      post = topic.posts.last
      upload = post.uploads.last

      expect(post.raw).to eq(<<~MD.chomp)
      **Before**

      <img src="#{upload.short_url}" alt="内嵌图片 1">

      *After*
      MD
    end

    it "gracefully handles malformed images in HTML part" do
      expect { process(:inline_image_2) }.to change { topic.posts.count }

      post = topic.posts.last
      upload = post.uploads.last

      expect(post.raw).to eq(<<~MD.chomp)
      [image:#{"0" * 5000}

      [details="#{I18n.t("emails.incoming.attachments")}"]

      #{UploadMarkdown.new(upload).to_markdown}

      [/details]
      MD
    end

    it "supports attached images in signature" do
      SiteSetting.incoming_email_prefer_html = true
      SiteSetting.always_show_trimmed_content = true

      expect { process(:body_with_image) }.to change { topic.posts.count }

      post = topic.posts.last
      upload = post.uploads.last

      expect(post.raw).to eq(<<~MD.chomp)
      This is a **GMAIL** reply ;)

      <details class='elided'>
      <summary title='Show trimmed content'>&#183;&#183;&#183;</summary>

      <img src="#{upload.short_url}" width="300" height="200">

      </details>
      MD
    end

    it "supports attachments" do
      SiteSetting.authorized_extensions = "txt|jpg"
      expect { process(:attached_txt_file) }.to change { topic.posts.count }
      post = topic.posts.last
      upload = post.uploads.first

      expect(post.raw).to eq(<<~MD.chomp)
      Please find some text file attached.

      [details="#{I18n.t("emails.incoming.attachments")}"]

      #{UploadMarkdown.new(upload).to_markdown}

      [/details]
      MD

      expect { process(:apple_mail_attachment) }.to change { topic.posts.count }
      post = topic.posts.last
      upload = post.uploads.first

      expect(post.raw).to eq(<<~MD.chomp)
      Picture below.

      <img apple-inline="yes" id="06C04C58-783E-4753-9B6B-D57403903060" src="#{upload.short_url}" class="">

      Picture above.
      MD
    end

    it "tries not to repeat duplicate attachments" do
      SiteSetting.authorized_extensions = "jpg"
      SiteSetting.always_show_trimmed_content = true

      expect { process(:logo_1) }.to change { Upload.count }.by(1)
      logo = Upload.last
      expect(topic.posts.last.raw).to include logo.short_url

      expect { process(:logo_2) }.not_to change { Upload.count }
      expect(topic.posts.last.raw).to include logo.short_url
    end

    it "works with removed attachments" do
      SiteSetting.authorized_extensions = "jpg"

      expect { process(:removed_attachments) }.to change { topic.posts.count }
      expect(topic.posts.last.uploads).to be_empty
    end

    it "supports eml attachments" do
      SiteSetting.authorized_extensions = "eml"
      expect { process(:attached_eml_file) }.to change { topic.posts.count }
      post = topic.posts.last
      upload = post.uploads.first

      expect(post.raw).to eq(<<~MD.chomp)
      Please find the eml file attached.

      [details="#{I18n.t("emails.incoming.attachments")}"]

      #{UploadMarkdown.new(upload).to_markdown}

      [/details]
      MD
    end

    it "can decode attachments" do
      SiteSetting.authorized_extensions = "pdf"
      Fabricate(:group, incoming_email: "one@foo.com")

      process(:encoded_filename)
      expect(Upload.last.original_filename).to eq("This is a test.pdf")
    end

    context "when attachment is rejected" do
      it "sends out the warning email" do
        expect { process(:attached_txt_file) }.to change { EmailLog.count }.by(1)
        expect(EmailLog.last.email_type).to eq("email_reject_attachment")
        expect(topic.posts.last.uploads.size).to eq 0
      end

      it "doesn't send out the warning email if sender is staged user" do
        user.update_columns(staged: true)
        expect { process(:attached_txt_file) }.not_to change { EmailLog.count }
        expect(topic.posts.last.uploads.size).to eq 0
      end

      it "creates the post with attachment missing message" do
        missing_attachment_regex =
          Regexp.escape(I18n.t("emails.incoming.missing_attachment", filename: "text.txt"))
        expect { process(:attached_txt_file) }.to change { topic.posts.count }
        post = topic.posts.last
        expect(post.raw).to match(/#{missing_attachment_regex}/)
        expect(post.uploads.size).to eq 0
      end
    end

    it "supports emails with just an attachment" do
      SiteSetting.authorized_extensions = "pdf"
      expect { process(:attached_pdf_file) }.to change { topic.posts.count }
      post = topic.posts.last
      upload = post.uploads.last

      expect(post.raw).to include UploadMarkdown.new(upload).to_markdown
    end

    it "supports liking via email" do
      expect { process(:like) }.to change(PostAction, :count)
    end

    it "ensures posts aren't dated in the future" do
      # PostCreator doesn't provide sub-second accuracy for created_at
      now = freeze_time Time.zone.now.round

      expect { process(:from_the_future) }.to change { topic.posts.count }
      expect(topic.posts.last.created_at).to eq_time(now)
    end

    it "accepts emails with wrong reply key if the system knows about the forwarded email" do
      Fabricate(:user, email: "bob@bar.com", refresh_auto_groups: true)
      Fabricate(
        :incoming_email,
        raw: <<~RAW,
                  Return-Path: <discourse@bar.com>
                  From: Alice <discourse@bar.com>
                  To: dave@bar.com, reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com
                  CC: carol@bar.com, bob@bar.com
                  Subject: Hello world
                  Date: Fri, 15 Jan 2016 00:12:43 +0100
                  Message-ID: <10@foo.bar.mail>
                  Mime-Version: 1.0
                  Content-Type: text/plain; charset=UTF-8
                  Content-Transfer-Encoding: quoted-printable

                  This post was created by email.
                RAW
        from_address: "discourse@bar.com",
        to_addresses: "dave@bar.com;reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com",
        cc_addresses: "carol@bar.com;bob@bar.com",
        topic: topic,
        post: post,
        user: user,
      )

      expect { process(:reply_user_not_matching_but_known) }.to change { topic.posts.count }
    end

    it "re-enables user's PM email notifications when user replies to a private topic" do
      topic.update_columns(category_id: nil, archetype: Archetype.private_message)
      topic.allowed_users << user
      topic.save

      user.user_option.update_columns(email_messages_level: UserOption.email_level_types[:never])
      expect { process(:reply_user_matching) }.to change { topic.posts.count }
      user.reload
      expect(user.user_option.email_messages_level).to eq(UserOption.email_level_types[:always])
    end
  end
end

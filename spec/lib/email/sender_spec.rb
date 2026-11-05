# frozen_string_literal: true

require "email/sender"

RSpec.describe Email::Sender do
  before { SiteSetting.secure_uploads_allow_embed_images_in_emails = false }

  fab!(:post)
  let(:mock_smtp_transaction_response) do
    "250 Ok: queued as 2l3Md07BObzB8kRyHZeoN0baSUAhzc7A-NviRioOr80=@mailhog.example"
  end

  def stub_deliver_response(message)
    message.stubs(:deliver!).returns(Net::SMTP::Response.new("250", mock_smtp_transaction_response))
  end

  it "renders recipient-visible tag hashtags as absolute links in HTML while retaining text hashtags" do
    recipient = Fabricate(:admin)
    tag = Fabricate(:tag)
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])
    body = "Tags: ##{tag.name}::tag"

    [[nil, []], [recipient, [tag.full_url]]].each do |user, expected_urls|
      message = Mail::Message.new(to: recipient.email, body:)
      stub_deliver_response(message)

      Email::Sender.new(message, :user_replied, user).send

      links = Nokogiri::HTML5.parse(message.html_part.body.decoded).css("a.hashtag-cooked")
      expect(links.map { |link| link["href"] }).to eq(expected_urls)
      expect(message.text_part.body.decoded).to eq(body)
    end
  end

  context "when disable_emails is enabled" do
    fab!(:user)
    fab!(:moderator)

    context "when disable_emails is enabled for everyone" do
      before { SiteSetting.disable_emails = "yes" }

      it "doesn't deliver mail when mails are disabled" do
        message = UserNotifications.email_login(moderator)
        Email::Sender.new(message, :email_login).send

        expect(ActionMailer::Base.deliveries).to eq([])
      end

      it "delivers mail when mails are disabled but the email_type is admin_login" do
        message = UserNotifications.admin_login(moderator)
        Email::Sender.new(message, :admin_login).send

        expect(ActionMailer::Base.deliveries.first.to).to eq([moderator.email])
      end

      it "delivers mail when mails are disabled but the email_type is test_message" do
        message = TestMailer.send_test(moderator.email)
        Email::Sender.new(message, :test_message).send

        expect(ActionMailer::Base.deliveries.first.to).to eq([moderator.email])
      end
    end

    context "when disable_emails is enabled for non-staff users" do
      before { SiteSetting.disable_emails = "non-staff" }

      it "doesn't deliver mail to normal user" do
        Mail::Message.any_instance.expects(:deliver!).never
        message = Mail::Message.new(to: user.email, body: "hello")
        stub_deliver_response(message)
        expect(Email::Sender.new(message, :hello).send).to eq(nil)
      end

      it "delivers mail to staff user" do
        Mail::Message.any_instance.expects(:deliver!).once
        message = Mail::Message.new(to: moderator.email, body: "hello")
        Email::Sender.new(message, :hello).send
      end

      it "delivers mail to staff user when confirming new email if user is provided" do
        Mail::Message.any_instance.expects(:deliver!).once
        Fabricate(
          :email_change_request,
          {
            user: moderator,
            new_email: "newemail@testmoderator.com",
            old_email: moderator.email,
            change_state: EmailChangeRequest.states[:authorizing_new],
          },
        )
        message = Mail::Message.new(to: "newemail@testmoderator.com", body: "hello")
        Email::Sender.new(message, :confirm_new_email, moderator).send
      end
    end
  end

  it "doesn't deliver mail when the message is of type NullMail" do
    Mail::Message.any_instance.expects(:deliver!).never
    message = ActionMailer::Base::NullMail.new
    expect(Email::Sender.new(message, :hello).send).to eq(nil)
  end

  it "doesn't deliver mail when the message is nil" do
    Mail::Message.any_instance.expects(:deliver!).never
    Email::Sender.new(nil, :hello).send
  end

  it "doesn't deliver when the to address is nil" do
    message = Mail::Message.new(body: "hello")
    message.expects(:deliver!).never
    Email::Sender.new(message, :hello).send
  end

  it "doesn't deliver when the to address uses the .invalid tld" do
    message = Mail::Message.new(body: "hello", to: "myemail@example.invalid")
    message.expects(:deliver!).never
    expect { Email::Sender.new(message, :hello).send }.to change {
      SkippedEmailLog.where(
        reason_type: SkippedEmailLog.reason_types[:sender_message_to_invalid],
      ).count
    }.by(1)
  end

  it "doesn't deliver when the body is nil" do
    message = Mail::Message.new(to: "eviltrout@test.domain")
    message.expects(:deliver!).never
    Email::Sender.new(message, :hello).send
  end

  describe ".host_for" do
    it "defaults to localhost" do
      expect(Email::Sender.host_for(nil)).to eq("localhost")
    end

    it "returns localhost for a weird host" do
      expect(Email::Sender.host_for("this is not a real host")).to eq("localhost")
    end

    it "parses hosts from urls" do
      expect(Email::Sender.host_for("http://meta.discourse.org")).to eq("meta.discourse.org")
    end

    it "downcases hosts" do
      expect(Email::Sender.host_for("http://ForumSite.com")).to eq("forumsite.com")
    end
  end

  context "with a valid message" do
    let(:reply_key) { "abcd" * 8 }

    let(:message) do
      message = Mail::Message.new(to: "eviltrout@test.domain", body: "**hello**")
      stub_deliver_response(message)
      message
    end

    let(:email_sender) { Email::Sender.new(message, :valid_type) }

    it "calls deliver" do
      message.expects(:deliver!).once
      email_sender.send
    end

    context "when no plus addressing" do
      before { SiteSetting.reply_by_email_address = "%{reply_key}@test.com" }

      it "leaves return_path unset" do
        email_sender.send
        expect(message.header[:return_path].to_s).to eq("")
      end
    end

    context "with plus addressing" do
      before { SiteSetting.reply_by_email_address = "replies+%{reply_key}@test.com" }

      it "sets return_path" do
        email_sender.send
        expect(message.header[:return_path].to_s).to eq(
          "replies+verp-#{EmailLog.last.bounce_key}@test.com",
        )
      end
    end

    context "when topic id is present" do
      fab!(:category) { Fabricate(:category, name: "Name With Space") }
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:post) { Fabricate(:post, topic: topic) }

      before do
        message.header["X-Discourse-Post-Id"] = post.id
        message.header["X-Discourse-Topic-Id"] = topic.id
      end

      it "adds the List-ID header" do
        email_sender.send

        expect(message.header["List-ID"]).to be_present
        expect(message.header["List-ID"].to_s).to match("name-with-space")
      end
    end

    context "when topic id is not present" do
      it "adds the Message-ID header" do
        email_sender.send

        expect(message.header["Message-ID"]).to be_present
      end
    end

    context "when reply_key is present" do
      fab!(:user)
      let(:email_sender) { Email::Sender.new(message, :valid_type, user) }
      let(:reply_key) { PostReplyKey.find_by!(post_id: post.id, user_id: user.id).reply_key }

      before do
        SiteSetting.reply_by_email_address = "replies+%{reply_key}@test.com"
        SiteSetting.email_custom_headers =
          "Auto-Submitted: auto-generated|Mail-Reply-To: sender-name+%{reply_key}@domain.net"

        message.header["X-Discourse-Post-Id"] = post.id
      end

      it "replaces headers with reply_key if present" do
        message.header[
          Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER
        ] = "test-%{reply_key}@test.com"
        message.header["Reply-To"] = "Test <test-%{reply_key}@test.com>"
        message.header["Auto-Submitted"] = "auto-generated"
        message.header["Mail-Reply-To"] = "sender-name+%{reply_key}@domain.net"

        email_sender.send

        expect(message.header["Reply-To"].to_s).to eq("Test <test-#{reply_key}@test.com>")
        expect(message.header["Auto-Submitted"].to_s).to eq("auto-generated")
        expect(message.header["Mail-Reply-To"].to_s).to eq("sender-name+#{reply_key}@domain.net")
      end

      it "removes headers with reply_key if absent" do
        message.header["Auto-Submitted"] = "auto-generated"
        message.header["Mail-Reply-To"] = "sender-name+%{reply_key}@domain.net"

        email_sender.send

        expect(message.header["Reply-To"].to_s).to eq("")
        expect(message.header["Auto-Submitted"].to_s).to eq("auto-generated")
        expect(message.header["Mail-Reply-To"].to_s).to eq("")
      end
    end

    describe "adds Precedence header" do
      fab!(:topic)
      fab!(:post) { Fabricate(:post, topic: topic) }

      before do
        message.header["X-Discourse-Post-Id"] = post.id
        message.header["X-Discourse-Topic-Id"] = topic.id
      end

      it "adds the Precedence header" do
        email_sender.send
        expect(message.header["Precedence"]).to be_present
      end
    end

    describe "removes custom Discourse headers from digest/registration/other mails" do
      it "removes custom Discourse headers" do
        email_sender.send
        expect(message.header["X-Discourse-Topic-Id"]).not_to be_present
        expect(message.header["X-Discourse-Topic-Ids"]).not_to be_present
        expect(message.header["X-Discourse-Post-Id"]).not_to be_present
        expect(message.header["X-Discourse-Reply-Key"]).not_to be_present
      end
    end

    describe "email threading" do
      fab!(:topic)

      fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
      fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }
      fab!(:post_3) { Fabricate(:post, topic: topic, post_number: 3) }
      fab!(:post_4) { Fabricate(:post, topic: topic, post_number: 4) }
      fab!(:post_5) { Fabricate(:post, topic: topic, post_number: 5) }
      fab!(:post_6) { Fabricate(:post, topic: topic, post_number: 6) }

      let!(:post_reply_1_4) { PostReply.create(post: post_1, reply: post_4) }
      let!(:post_reply_2_4) { PostReply.create(post: post_2, reply: post_4) }
      let!(:post_reply_3_4) { PostReply.create(post: post_3, reply: post_4) }
      let!(:post_reply_4_5) { PostReply.create(post: post_4, reply: post_5) }
      let!(:post_reply_4_6) { PostReply.create(post: post_4, reply: post_6) }
      let!(:post_reply_5_6) { PostReply.create(post: post_5, reply: post_6) }

      before { message.header["X-Discourse-Topic-Id"] = topic.id }

      it "doesn't set References or In-Reply-To headers on the first post, only generates a Message-ID and saves it against the post" do
        message.header["X-Discourse-Post-Id"] = post_1.id

        email_sender.send
        post_1.reload

        expect(message.header["Message-Id"].to_s).to eq(
          "<discourse/post/#{post_1.id}@test.localhost>",
        )
        expect(post_1.outbound_message_id).to eq("discourse/post/#{post_1.id}@test.localhost")
        expect(message.header["In-Reply-To"].to_s).to be_blank
        expect(message.header["References"].to_s).to be_blank
      end

      it "uses the existing Message-ID header from the incoming email when sending the first post email" do
        incoming =
          Fabricate(
            :incoming_email,
            topic: topic,
            post: post_1,
            message_id: "blah1234@someemailprovider.com",
            created_via: IncomingEmail.created_via_types[:handle_mail],
          )
        post_1.update!(outbound_message_id: incoming.message_id)
        message.header["X-Discourse-Post-Id"] = post_1.id

        email_sender.send

        expect(message.header["Message-Id"].to_s).to eq("<blah1234@someemailprovider.com>")
        expect(message.header["In-Reply-To"].to_s).to be_blank
        expect(message.header["References"].to_s).to be_blank
      end

      it "if no post is directly replied to then the Message-ID of post 1 via outbound_message_id should be used" do
        message.header["X-Discourse-Post-Id"] = post_2.id

        email_sender.send

        expect(message.header["Message-Id"].to_s).to eq(
          "<discourse/post/#{post_2.id}@test.localhost>",
        )
        expect(message.header["In-Reply-To"].to_s).to eq(
          "<discourse/post/#{post_1.id}@test.localhost>",
        )
        expect(message.header["References"].to_s).to eq(
          "<discourse/post/#{post_1.id}@test.localhost>",
        )
      end

      it "sets the References header to the most recently created replied post, as well as the OP, if there are no other replies in the chain" do
        message.header["X-Discourse-Post-Id"] = post_4.id

        email_sender.send

        expect(message.header["Message-ID"].to_s).to eq(
          "<discourse/post/#{post_4.id}@test.localhost>",
        )
        expect(message.header["References"].to_s).to eq(
          "<discourse/post/#{post_1.id}@test.localhost> <discourse/post/#{post_3.id}@test.localhost>",
        )
      end

      it "sets the In-Reply-To header to all the posts that the post is connected to via PostReply" do
        message.header["X-Discourse-Post-Id"] = post_6.id

        email_sender.send

        expect(message.header["Message-ID"].to_s).to eq(
          "<discourse/post/#{post_6.id}@test.localhost>",
        )
        expect(message.header["In-Reply-To"].to_s).to eq(
          "<discourse/post/#{post_4.id}@test.localhost> <discourse/post/#{post_5.id}@test.localhost>",
        )
      end

      it "sets the In-Reply-To and References header to the most recently created replied post and includes the parents of that post in References, as well as the OP" do
        message.header["X-Discourse-Post-Id"] = post_4.id
        PostReply.create(post: post_2, reply: post_3)

        email_sender.send

        expect(message.header["Message-ID"].to_s).to eq(
          "<discourse/post/#{post_4.id}@test.localhost>",
        )
        expect(message.header["In-Reply-To"].to_s).to eq(
          "<discourse/post/#{post_1.id}@test.localhost> <discourse/post/#{post_2.id}@test.localhost> <discourse/post/#{post_3.id}@test.localhost>",
        )

        references = [
          "<discourse/post/#{post_1.id}@test.localhost>",
          "<discourse/post/#{post_2.id}@test.localhost>",
          "<discourse/post/#{post_3.id}@test.localhost>",
        ]
        expect(message.header["References"].to_s).to eq(references.join(" "))
      end

      it "handles a complex reply tree to the OP for References, only using one Message-ID if there are multiple parents for a post" do
        message.header["X-Discourse-Post-Id"] = post_6.id
        PostReply.create(post: post_2, reply: post_6)

        email_sender.send

        expect(message.header["Message-ID"].to_s).to eq(
          "<discourse/post/#{post_6.id}@test.localhost>",
        )
        expect(message.header["In-Reply-To"].to_s).to eq(
          "<discourse/post/#{post_2.id}@test.localhost> <discourse/post/#{post_4.id}@test.localhost> <discourse/post/#{post_5.id}@test.localhost>",
        )

        references = [
          "<discourse/post/#{post_1.id}@test.localhost>",
          "<discourse/post/#{post_3.id}@test.localhost>",
          "<discourse/post/#{post_4.id}@test.localhost>",
          "<discourse/post/#{post_5.id}@test.localhost>",
        ]
        expect(message.header["References"].to_s).to eq(references.join(" "))
      end
    end

    describe "merges custom mandrill header" do
      before do
        ActionMailer::Base.smtp_settings[:address] = "smtp.mandrillapp.com"
        message.header["X-MC-Metadata"] = { foo: "bar" }.to_json
      end

      it "adds the message ID to the Mandrill metadata" do
        email_sender.send
        expect(message.header["X-MC-Metadata"].to_s).to match(message.message_id)
      end
    end

    describe "merges custom sparkpost header" do
      before do
        ActionMailer::Base.smtp_settings[:address] = "smtp.sparkpostmail.com"
        message.header["X-MSYS-API"] = { foo: "bar" }.to_json
      end

      it "adds the message ID to the SparkPost metadata" do
        email_sender.send
        expect(message.header["X-MSYS-API"].to_s).to match(message.message_id)
      end
    end

    context "with email logs" do
      let(:email_log) { EmailLog.last }

      it "creates an email log without a reply key" do
        expect do email_sender.send end.to_not change { PostReplyKey.count }

        expect(email_log).to be_present
        expect(email_log.email_type).to eq("valid_type")
        expect(email_log.to_address).to eq("eviltrout@test.domain")
        expect(email_log.user_id).to be_blank
        expect(email_log.raw).to eq(nil)
      end

      context "when the email is sent using group SMTP credentials" do
        let(:reply) do
          Fabricate(
            :post,
            topic: post.topic,
            reply_to_user: post.user,
            reply_to_post_number: post.post_number,
          )
        end
        let(:notification) { Fabricate(:posted_notification, user: post.user, post: reply) }
        let(:message) { GroupSmtpMailer.send_mail(group, post.user.email, post) }
        let(:group) { Fabricate(:smtp_group) }

        before do
          SiteSetting.enable_smtp = true
          stub_deliver_response(message)
        end

        it "adds the group id and raw content to the email log" do
          TopicAllowedGroup.create(topic: post.topic, group: group)

          email_sender.send

          expect(email_log).to be_present
          expect(email_log.email_type).to eq("valid_type")
          expect(email_log.to_address).to eq(post.user.email)
          expect(email_log.user_id).to be_blank
          expect(email_log.smtp_group_id).to eq(group.id)
          expect(email_log.raw).to include("Hello world")
        end

        it "does not add any of the mailing list headers" do
          TopicAllowedGroup.create(topic: post.topic, group: group)
          email_sender.send

          expect(message.header["List-ID"]).to eq(nil)
          expect(message.header["List-Archive"]).to eq(nil)
          expect(message.header["Precedence"]).to eq(nil)
          expect(message.header["List-Unsubscribe"]).to eq(nil)
        end

        it "removes the Auto-Submitted header" do
          TopicAllowedGroup.create!(topic: post.topic, group: group)
          email_sender.send

          expect(message.header["Auto-Submitted"]).to eq(nil)
        end
      end
    end

    context "with email log with a post id and topic id" do
      let(:topic) { post.topic }

      before do
        message.header["X-Discourse-Post-Id"] = post.id
        message.header["X-Discourse-Topic-Id"] = topic.id
      end

      let(:email_log) { EmailLog.last }

      it "records the post and topic in the email log" do
        email_sender.send
        expect(email_log.post_id).to eq(post.id)
        expect(email_log.topic_id).to eq(topic.id)
        expect(email_log.topic.id).to eq(topic.id)
      end
    end

    context "with email parts" do
      it "builds matching plain-text and HTML email parts" do
        email_sender.send

        expect(message).to be_multipart
        expect(message.text_part.content_type).to eq("text/plain; charset=UTF-8")
        expect(message.html_part.content_type).to eq("text/html; charset=UTF-8")
        expect(message.html_part.body.to_s).to match("<p><strong>hello</strong></p>")
      end
    end
  end

  context "with attachments" do
    fab!(:small_pdf) do
      SiteSetting.authorized_extensions = "pdf"
      UploadCreator.new(file_from_fixtures("small.pdf", "pdf"), "small.pdf").create_for(
        Discourse.system_user.id,
      )
    end
    fab!(:large_pdf) do
      SiteSetting.authorized_extensions = "pdf"
      UploadCreator.new(file_from_fixtures("large.pdf", "pdf"), "large.pdf").create_for(
        Discourse.system_user.id,
      )
    end
    fab!(:csv_file) do
      SiteSetting.authorized_extensions = "csv"
      UploadCreator.new(file_from_fixtures("words.csv", "csv"), "words.csv").create_for(
        Discourse.system_user.id,
      )
    end
    fab!(:image) do
      SiteSetting.authorized_extensions = "png"
      UploadCreator.new(file_from_fixtures("logo.png", "images"), "logo.png").create_for(
        Discourse.system_user.id,
      )
    end
    fab!(:post)
    fab!(:reply) do
      raw = <<~RAW
        Hello world! It’s a great day!
        #{UploadMarkdown.new(small_pdf).attachment_markdown}
        #{UploadMarkdown.new(large_pdf).attachment_markdown}
        #{UploadMarkdown.new(image).image_markdown}
        #{UploadMarkdown.new(csv_file).attachment_markdown}
      RAW
      reply =
        Fabricate(
          :post,
          raw: raw,
          topic: post.topic,
          user: Fabricate(:user, refresh_auto_groups: true),
        )
      reply.link_post_uploads
      reply
    end
    fab!(:notification) { Fabricate(:posted_notification, user: post.user, post: reply) }
    let(:message) do
      UserNotifications.user_posted(
        post.user,
        post: reply,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash,
      )
    end

    context "with a plugin" do
      before { DiscoursePluginRegistry.clear_modifiers! }
      after { DiscoursePluginRegistry.clear_modifiers! }

      it "allows plugins to control whether attachments are included" do
        SiteSetting.email_total_attachment_size_limit_kb = 10_000

        Plugin::Instance.new.register_modifier(:should_add_email_attachments) { false }

        Email::Sender.new(message, :valid_type).send
        expect(message.attachments.size).to eq(0)
      end
    end

    it "adds only non-image uploads as attachments to the email" do
      SiteSetting.email_total_attachment_size_limit_kb = 10_000
      Email::Sender.new(message, :valid_type).send

      expect(message.attachments.length).to eq(3)
      expect(message.attachments.map(&:filename)).to contain_exactly(
        *[small_pdf, large_pdf, csv_file].map(&:original_filename),
      )
    end

    it "changes hashtags to their slug with a # symbol rather than the full resource name" do
      category = Fabricate(:category, slug: "dev")
      reply.update!(raw: reply.raw + "\n wow this is #dev")
      reply.rebake!
      Email::Sender.new(message, :valid_type).send
      expected = <<~HTML
          <a class="hashtag-cooked" href="#{Discourse.base_url}#{category.url}" data-type="category" data-slug="dev" data-id="#{category.id}" data-style-type="square" style="text-decoration:none;font-weight:bold;color:#006699">#dev</a>
        HTML
      expect(message.html_part.body.to_s).to include(expected.chomp)
    end

    context "when secure uploads enabled" do
      before do
        setup_s3
        stub_s3_store

        SiteSetting.secure_uploads = true
        SiteSetting.login_required = true
        SiteSetting.email_total_attachment_size_limit_kb = 14_000
        SiteSetting.secure_uploads_max_email_embed_image_size_kb = 5_000

        Jobs.run_immediately!
        Jobs::PullHotlinkedImages.any_instance.expects(:execute).at_least_once
        FileStore::S3Store.any_instance.expects(:has_been_uploaded?).returns(true).at_least_once
        CookedPostProcessor.any_instance.stubs(:get_size).returns([244, 66])

        @secure_image_file = file_from_fixtures("logo.png", "images")
        @secure_image =
          UploadCreator.new(@secure_image_file, "secure_logo.png").create_for(
            Discourse.system_user.id,
          )
        @secure_image.update_secure_status(override: true)
        @secure_image.update(access_control_post_id: reply.id)
        reply.update!(raw: reply.raw + "\n" + "#{UploadMarkdown.new(@secure_image).image_markdown}")
        reply.uploads << @secure_image
        reply.save
        reply.rebake!
      end

      it "does not attach images when embedding them is not allowed" do
        Email::Sender.new(message, :valid_type).send
        expect(message.attachments.length).to eq(3)
      end

      context "when embedding secure images in email is allowed" do
        before { SiteSetting.secure_uploads_allow_embed_images_in_emails = true }

        it "can inline images with duplicate names" do
          @secure_image_2 =
            UploadCreator.new(
              file_from_fixtures("logo-dev.png", "images"),
              "secure_logo_2.png",
            ).create_for(Discourse.system_user.id)
          @secure_image_2.update_secure_status(override: true)
          @secure_image_2.update(access_control_post_id: reply.id)

          Jobs::PullHotlinkedImages.any_instance.expects(:execute)
          reply.update(
            raw:
              "#{UploadMarkdown.new(@secure_image).image_markdown}\n#{UploadMarkdown.new(@secure_image_2).image_markdown}",
          )
          reply.rebake!

          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.size).to eq(2)
          expect(message.to_s.scan(/cid:[\w\-@.]+/).length).to eq(2)
          expect(message.to_s.scan(/cid:[\w\-@.]+/).uniq.length).to eq(2)
        end

        it "attaches only allowed images from multiple posts in the activity summary" do
          digest_post = Fabricate(:post)
          other_digest_post = Fabricate(:post)

          SiteSetting.authorized_extensions = "*"

          Topic.stubs(:for_digest).returns(
            Topic.where(id: [digest_post.topic_id, other_digest_post.topic_id]),
          )

          summary = UserNotifications.digest(post.user, since: 24.hours.ago)

          @secure_image_2 =
            UploadCreator.new(
              file_from_fixtures("logo.png", "images"),
              "something-cool.png",
            ).create_for(Discourse.system_user.id)
          @secure_image_2.update_secure_status(override: true)
          @secure_image_2.update(access_control_post_id: digest_post.id)

          @secure_image_3 =
            UploadCreator.new(
              file_from_fixtures("logo.png", "images"),
              "something-cooler.png",
            ).create_for(Discourse.system_user.id)
          @secure_image_3.update_secure_status(override: true)
          @secure_image_3.update(access_control_post_id: other_digest_post.id)

          @secure_attachment =
            UploadCreator.new(
              file_from_fixtures("small.pdf", "pdf"),
              "cool-attachment.pdf",
            ).create_for(Discourse.system_user.id)
          @secure_attachment.update_secure_status(override: true)
          @secure_attachment.update(access_control_post_id: other_digest_post.id)

          @secure_video =
            UploadCreator.new(
              file_from_fixtures("small.mp4", "media"),
              "cool-video.mp4",
            ).create_for(Discourse.system_user.id)
          @secure_video.update_secure_status(override: true)
          @secure_video.update(access_control_post_id: other_digest_post.id)

          Jobs::PullHotlinkedImages.any_instance.expects(:execute)

          # Crafted so that the second image is not in the excerpt.
          raw = <<~MD
            IMAGE #1
            #{UploadMarkdown.new(@secure_image).image_markdown}

            > 11:15, restate my assumptions:
            >
            >   1. Mathematics is the language of nature.
            >   2. Everything around us can be represented and understood through numbers.
            >   3. If you graph these numbers, patterns emerge.
            >
            > Therefore: There are patterns everywhere in nature.

            IMAGE #2
            #{UploadMarkdown.new(@secure_image_2).image_markdown}
          MD

          digest_post.update(raw:)
          digest_post.rebake!

          expect(digest_post.upload_references.size).to eq(2)

          raw = <<~MD
            IMAGE #3
            #{UploadMarkdown.new(@secure_image_3).image_markdown}

            ATTACHMENT
            #{UploadMarkdown.new(@secure_attachment).attachment_markdown}

            VIDEO
            #{UploadMarkdown.new(@secure_video).playable_media_markdown}
          MD

          other_digest_post.update(raw:)
          other_digest_post.rebake!

          expect(other_digest_post.upload_references.size).to eq(3)

          summary.header["X-Discourse-Post-Id"] = nil
          summary.header["X-Discourse-Post-Ids"] = "#{digest_post.id},#{other_digest_post.id}"

          Email::Sender.new(summary, "digest").send

          expect(summary.content_type).to eq(
            "multipart/mixed; boundary=\"#{summary.body.boundary}\"",
          )
          expect(summary.attachments.map(&:filename)).to contain_exactly(
            *[@secure_image, @secure_image_3].map(&:original_filename),
          )
          expect(summary.attachments.size).to eq(2)
          expect(summary.to_s.scan("Content-Type: text/html;").length).to eq(1)
          expect(summary.to_s.scan("Content-Type: text/plain;").length).to eq(1)
          expect(summary.to_s.scan(/cid:[\w\-@.]+/).length).to eq(2)
          expect(summary.to_s.scan(/cid:[\w\-@.]+/).uniq.length).to eq(2)
        end

        it "does not attach images that are not marked as secure, in the case of a non-secure upload copied to a PM" do
          SiteSetting.login_required = false
          @secure_image.update_secure_status(override: false)
          @secure_image.update!(access_control_post: Fabricate(:post))
          pm_topic = Fabricate(:private_message_topic)
          Fabricate(:post, topic: pm_topic)
          reply.update(topic: pm_topic)
          reply.rebake!
          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.length).to eq(4)
        end

        it "does not embed images that are too big" do
          SiteSetting.secure_uploads_max_email_embed_image_size_kb = 1
          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.length).to eq(3)
        end

        it "uses the email styles to inline secure images and attaches the secure image upload to the email" do
          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.length).to eq(5)
          expect(message.attachments.map(&:filename)).to contain_exactly(
            *[small_pdf, large_pdf, csv_file, image, @secure_image].map(&:original_filename),
          )
          expect(message.attachments["logo.png"].body.raw_source.force_encoding("UTF-8")).to eq(
            File.read(@secure_image_file),
          )
          expect(message.html_part.body).to include("cid:")
          expect(message.html_part.body).to include("embedded-secure-image")
        end

        it "embeds an image with a secure URL that has an upload that is not secure" do
          @secure_image.update_secure_status(override: false)
          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.length).to eq(5)
          expect(message.attachments["logo.png"].body.raw_source.force_encoding("UTF-8")).to eq(
            File.read(@secure_image_file),
          )
        end

        it "uses correct UTF-8 encoding for the body of the email" do
          Email::Sender.new(message, :valid_type).send
          expect(message.html_part.body).not_to include("Itâ\u0080\u0099s")
          expect(message.html_part.body).to include("It’s")
          expect(message.html_part.charset.downcase).to eq("utf-8")
        end

        context "when the uploaded secure image has an optimized image" do
          let!(:optimized) { Fabricate(:optimized_image, upload: @secure_image) }
          let!(:optimized_image_file) { file_from_fixtures("smallest.png", "images") }

          before do
            url = Discourse.store.store_optimized_image(optimized_image_file, optimized)
            optimized.update(url: Discourse.store.absolute_base_url + "/" + url)
            Discourse.store.cache_file(optimized_image_file, File.basename("#{optimized.sha1}.png"))
          end

          it "uses the email styles and the optimized image to inline secure images and attaches the secure image upload to the email" do
            Email::Sender.new(message, :valid_type).send
            expect(message.attachments.length).to eq(5)
            expect(message.attachments.map(&:filename)).to contain_exactly(
              *[small_pdf, large_pdf, csv_file, image, @secure_image].map(&:original_filename),
            )
            expect(
              message.attachments["secure_logo.png"].body.raw_source.force_encoding("UTF-8"),
            ).to eq(File.read(optimized_image_file))
            expect(message.html_part.body).to include("cid:")
            expect(message.html_part.body).to include("embedded-secure-image")
          end

          it "uses the optimized image size in the max size limit calculation, not the original image size" do
            SiteSetting.email_total_attachment_size_limit_kb = 45
            Email::Sender.new(message, :valid_type).send
            expect(message.attachments.length).to eq(4)
            expect(
              message.attachments["secure_logo.png"].body.raw_source.force_encoding("UTF-8"),
            ).to eq(File.read(optimized_image_file))
          end
        end
      end
    end

    it "adds only non-image uploads as attachments to the email and leaves the image intact with original source" do
      SiteSetting.email_total_attachment_size_limit_kb = 10_000
      Email::Sender.new(message, :valid_type).send

      expect(message.attachments.length).to eq(3)
      expect(message.attachments.map(&:filename)).to contain_exactly(
        *[small_pdf, large_pdf, csv_file].map(&:original_filename),
      )
      expect(message.html_part.body).to include("<img src=\"#{Discourse.base_url}#{image.url}\"")
    end

    it "respects the size limit and attaches only files that fit into the max email size" do
      SiteSetting.email_total_attachment_size_limit_kb = 40
      Email::Sender.new(message, :valid_type).send

      expect(message.attachments.length).to eq(2)
      expect(message.attachments.map(&:filename)).to contain_exactly(
        *[small_pdf, csv_file].map(&:original_filename),
      )
    end

    it "structures the email as a multipart/mixed with a multipart/alternative first part" do
      SiteSetting.email_total_attachment_size_limit_kb = 10_000
      Email::Sender.new(message, :valid_type).send

      expect(message.content_type).to start_with("multipart/mixed")
      expect(message.parts.size).to eq(4)
      expect(message.parts[0].content_type).to start_with("multipart/alternative")
      expect(message.parts[0].parts.size).to eq(2)
    end

    it "uses correct UTF-8 encoding for the body of the email" do
      Email::Sender.new(message, :valid_type).send
      expect(message.html_part.body).not_to include("Itâ\u0080\u0099s")
      expect(message.html_part.body).to include("It’s")
      expect(message.html_part.charset.downcase).to eq("utf-8")
    end
  end

  context "with a deleted post" do
    it "skips the email and records the deleted-post reason" do
      post = Fabricate(:post, deleted_at: 1.day.ago)

      message = Mail::Message.new to: "disc@ourse.org", body: "some content"
      message.header["X-Discourse-Post-Id"] = post.id
      message.header["X-Discourse-Topic-Id"] = post.topic_id
      message.expects(:deliver!).never

      email_sender = Email::Sender.new(message, :valid_type)
      expect { email_sender.send }.to change { SkippedEmailLog.count }

      log = SkippedEmailLog.last
      expect(log.reason_type).to eq(SkippedEmailLog.reason_types[:sender_post_deleted])
    end
  end

  context "with a deleted topic" do
    it "skips the email and records the deleted-topic reason" do
      post = Fabricate(:post, topic: Fabricate(:topic, deleted_at: 1.day.ago))

      message = Mail::Message.new to: "disc@ourse.org", body: "some content"
      message.header["X-Discourse-Post-Id"] = post.id
      message.header["X-Discourse-Topic-Id"] = post.topic_id
      message.expects(:deliver!).never

      email_sender = Email::Sender.new(message, :valid_type)
      expect { email_sender.send }.to change { SkippedEmailLog.count }

      log = SkippedEmailLog.last
      expect(log.reason_type).to eq(SkippedEmailLog.reason_types[:sender_topic_deleted])
    end
  end

  context "with a user" do
    let(:message) do
      message = Mail::Message.new to: "eviltrout@test.domain", body: "test body"
      stub_deliver_response(message)
      message
    end

    fab!(:user)
    let(:email_sender) { Email::Sender.new(message, :valid_type, user) }

    before do
      email_sender.send
      @email_log = EmailLog.last
    end

    it "records the current user ID" do
      expect(@email_log.user_id).to eq(user.id)
    end

    it "records the SMTP transaction response" do
      expect(@email_log.smtp_transaction_response).to eq(mock_smtp_transaction_response)
    end

    describe "post reply keys" do
      fab!(:post)

      before do
        message.header["X-Discourse-Post-Id"] = post.id
        message.header["Reply-To"] = "test-%{reply_key}@test.com"
      end

      describe "when allow reply by email header is not present" do
        it "does not create a post reply key" do
          expect { email_sender.send }.to_not change { PostReplyKey.count }
        end
      end

      describe "when allow reply by email header is present" do
        let(:header) { Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER }

        before { message.header[header] = "test-%{reply_key}@test.com" }

        it "creates a post reply key" do
          expect { email_sender.send }.to change { PostReplyKey.count }.by(1)
          post_reply_key = PostReplyKey.last

          expect(message.header["Reply-To"].value).to eq(
            "test-#{post_reply_key.reply_key}@test.com",
          )

          expect(message.header[header]).to eq(nil)
          expect(post_reply_key.user_id).to eq(user.id)
          expect(post_reply_key.post_id).to eq(post.id)
          expect { email_sender.send }.not_to change { PostReplyKey.count }
        end

        it "reuses the existing post reply key" do
          existing_post_reply_key = PostReplyKey.create(post_id: post.id, user_id: user.id)
          expect { email_sender.send }.not_to change { PostReplyKey.count }
          post_reply_key = PostReplyKey.last
          expect(post_reply_key).to eq(existing_post_reply_key)
        end
      end
    end
  end

  context "with cc addresses" do
    let(:message) do
      message =
        Mail::Message.new to: "eviltrout@test.domain",
                          body: "test body",
                          cc: "someguy@test.com;otherguy@xyz.com"
      stub_deliver_response(message)
      message
    end

    fab!(:user)
    let(:email_sender) { Email::Sender.new(message, :valid_type, user) }

    it "logs the cc addresses in the email log (but not users if they do not match the emails)" do
      email_sender.send
      email_log = EmailLog.last
      expect(email_log.cc_addresses).to eq("someguy@test.com;otherguy@xyz.com")
      expect(email_log.cc_users).to eq([])
    end

    it "logs the cc users if they match the emails" do
      user1 = Fabricate(:user, email: "someguy@test.com")
      user2 = Fabricate(:user, email: "otherguy@xyz.com")
      email_sender.send
      email_log = EmailLog.last
      expect(email_log.cc_addresses).to eq("someguy@test.com;otherguy@xyz.com")
      expect(email_log.cc_users).to match_array([user1, user2])
    end
  end

  context "with Net::SMTPError" do
    let(:message) { Mail::Message.new(to: "eviltrout@test.domain", body: "test body") }

    let(:email_sender) { Email::Sender.new(message, :valid_type) }

    it "logs the error and re-raises" do
      error = Net::SMTPUnknownError.new("550 Unknown SMTP response")
      message.expects(:deliver!).raises(error)
      Rails
        .logger
        .expects(:error)
        .with("SMTP Error Net::SMTPUnknownError with message: 550 Unknown SMTP response")

      expect { email_sender.send }.to raise_error(Net::SMTPUnknownError)
    end

    it "logs the server response if available" do
      error = Net::SMTPUnknownError.new("550 Unknown SMTP response")
      smtp_response = Net::SMTP::Response.new("550", "5.7.1 Relaying denied")
      error.define_singleton_method(:response) { smtp_response }
      message.expects(:deliver!).raises(error)

      Rails
        .logger
        .expects(:error) do |log_message|
          expect(log_message).to include("SMTP Error Net::SMTPUnknownError")
          expect(log_message).to include("550 Unknown SMTP response")
          expect(log_message).to include("response:")
          expect(log_message).to include("5.7.1 Relaying denied")
        end

      expect { email_sender.send }.to raise_error(Net::SMTPUnknownError)
    end

    it "does not log unreadable object representation" do
      error = Net::SMTPUnknownError.new("550 Unknown SMTP response")
      smtp_response = Net::SMTP::Response.new("550", "5.7.1 Relaying denied")
      def error.response
        Net::SMTP::Response.new("550", "5.7.1 Relaying denied")
      end
      message.expects(:deliver!).raises(error)

      Rails
        .logger
        .expects(:error) do |log_message|
          expect(log_message).not_to include("#<Net::SMTP::Response:")
          expect(log_message).to include("550 5.7.1 Relaying denied")
        end

      expect { email_sender.send }.to raise_error(Net::SMTPUnknownError)
    end

    it "handles error without server response gracefully" do
      error = Net::SMTPUnknownError.new("550 Unknown SMTP response")
      message.expects(:deliver!).raises(error)

      Rails
        .logger
        .expects(:error)
        .with("SMTP Error Net::SMTPUnknownError with message: 550 Unknown SMTP response")

      expect { email_sender.send }.to raise_error(Net::SMTPUnknownError)
    end

    it "handles truthy response that does not respond to .string" do
      error = Net::SMTPUnknownError.new("some error")
      def error.response
        "not a response object"
      end
      message.expects(:deliver!).raises(error)

      Rails
        .logger
        .expects(:error)
        .with(
          "SMTP Error Net::SMTPUnknownError with message: some error response: not a response object",
        )

      expect { email_sender.send }.to raise_error(Net::SMTPUnknownError)
    end
  end

  context "with Net::SMTPFatalError" do
    let(:message) { Mail::Message.new(to: "eviltrout@test.domain", body: "test body") }
    let(:email_sender) { Email::Sender.new(message, :valid_type) }

    it "stores the SMTP response string as custom reason" do
      error = Net::SMTPFatalError.new("552-5.7.0 This message was blocked")
      smtp_response =
        Net::SMTP::Response.new(
          "552",
          "552-5.7.0 This message was blocked because its content presents a potential\n552 5.7.0 issue",
        )
      error.define_singleton_method(:response) { smtp_response }
      message.expects(:deliver!).raises(error)

      expect { email_sender.send }.to change(SkippedEmailLog, :count).by(1)

      skipped_email_log = SkippedEmailLog.last
      expect(skipped_email_log.reason_type).to eq(SkippedEmailLog.reason_types[:custom])
      expect(skipped_email_log.custom_reason).to eq(
        "552-5.7.0 This message was blocked because its content presents a potential\n552 5.7.0 issue",
      )
    end

    context "when the email is related to a PM topic" do
      fab!(:pm_creator, :user)
      fab!(:pm_target, :user)
      fab!(:pm_topic) { Fabricate(:private_message_topic, user: pm_creator, recipient: pm_target) }
      fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: pm_creator) }

      before do
        SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
        message.header["X-Discourse-Post-Id"] = pm_post.id
        message.header["X-Discourse-Topic-Id"] = pm_topic.id
      end

      it "creates a staff whisper with the SMTP failure details" do
        error = Net::SMTPFatalError.new("552-5.7.0 This message was blocked")
        smtp_response =
          Net::SMTP::Response.new(
            "552",
            "552-5.7.0 This message was blocked because its content presents a potential\n552 5.7.0 issue",
          )
        error.define_singleton_method(:response) { smtp_response }
        message.expects(:deliver!).raises(error)

        expect { email_sender.send }.to change {
          Post.where(topic_id: pm_topic.id, post_type: Post.types[:whisper]).count
        }.by(1)

        whisper = Post.where(topic_id: pm_topic.id, post_type: Post.types[:whisper]).last
        expect(whisper.user).to eq(Discourse.system_user)
        expect(whisper.raw).to eq(
          I18n.t(
            "system_messages.email_sending_failed",
            email: "eviltrout@test.domain",
            raw:
              "552-5.7.0 This message was blocked because its content presents a potential\n552 5.7.0 issue",
          ).strip,
        )
      end
    end
  end

  describe "critical SMTP routing" do
    fab!(:user)

    let(:default_settings) do
      {
        address: "default.example.com",
        port: 587,
        domain: "default-helo.example.com",
        user_name: "default-user",
        password: "default-password",
        authentication: :login,
        enable_starttls_auto: false,
        tls: true,
        openssl_verify_mode: "none",
        open_timeout: 20,
        read_timeout: 40,
      }
    end
    let(:delivered) { [] }
    let(:smtp_response) { Net::SMTP::Response.new("250", "250 queued as critical-message\r\n") }

    def delivered_addresses
      delivered.map { |message| message.delivery_method.settings[:address] }
    end

    around do |example|
      original_settings = ActionMailer::Base.smtp_settings
      original_method = ActionMailer::Base.delivery_method
      example.run
    ensure
      ActionMailer::Base.smtp_settings = original_settings
      ActionMailer::Base.delivery_method = original_method
    end

    before do
      ActionMailer::Base.delivery_method = :smtp
      ActionMailer::Base.smtp_settings = default_settings
      global_setting :critical_smtp_address, "critical.example.com"
      Mail::SMTP
        .any_instance
        .stubs(:deliver!)
        .with do |message|
          delivered << message
          true
        end
        .returns(smtp_response)
    end

    it "keeps the default transport when critical SMTP is disabled" do
      global_setting :critical_smtp_address, nil
      message = UserNotifications.forgot_password(user, email_token: "reset-token").message
      transport = message.delivery_method

      Email::Sender.new(message, :forgot_password, user).send

      expect(delivered).to eq([message])
      expect(message.delivery_method).to equal(transport)
      expect(transport.settings).to include(default_settings)
    end

    it "preserves disabled-email behavior and the existing admin-login exception" do
      SiteSetting.disable_emails = "yes"
      Jobs::CriticalUserEmail.new.execute(user_id: user.id, type: "forgot_password")
      Jobs::CriticalUserEmail.new.execute(user_id: user.id, type: "admin_login")

      expect(delivered.size).to eq(1)
      expect(EmailLog.last.email_type).to eq("admin_login")
      expect(delivered_addresses).to eq(["critical.example.com"])
    end

    it "preserves login-link rate and bounce limits without adding routing types to exemptions" do
      SiteSetting.max_emails_per_day_per_user = 1
      Jobs::CriticalUserEmail.new.execute(user_id: user.id, type: "signup")
      Jobs::CriticalUserEmail.new.execute(user_id: user.id, type: "email_login")

      expect(SkippedEmailLog.last.reason_type).to eq(
        SkippedEmailLog.reason_types[:exceeded_emails_limit],
      )

      SiteSetting.max_emails_per_day_per_user = 0
      user.user_stat.update!(bounce_score: SiteSetting.bounce_score_threshold)
      Jobs::CriticalUserEmail.new.execute(user_id: user.id, type: "email_login")

      expect(SkippedEmailLog.last.reason_type).to eq(
        SkippedEmailLog.reason_types[:exceeded_bounces_limit],
      )
      expect(delivered.size).to eq(1)
    end

    %w[
      signup
      activation_reminder
      forgot_password
      account_created
      email_login
      admin_login
      confirm_old_email
      confirm_old_email_add
      confirm_new_email
    ].each do |type|
      it "routes the real #{type} mailer through the account email job" do
        job =
          if %w[activation_reminder account_created].include?(type)
            Jobs::UserEmail.new
          else
            Jobs::CriticalUserEmail.new
          end
        job.execute(user_id: user.id, type: type, email_token: "account-access-token")

        expect(delivered.size).to eq(1)
        message = delivered.first
        expect(message.to).to eq([user.email])
        expect(message.text_part.decoded).to include("account-access-token")
        expect(delivered_addresses).to eq(["critical.example.com"])
        expect(EmailLog.last.email_type).to eq(type)
      end
    end

    it "routes login and password reset codes through their independent job" do
      SiteSetting.enable_local_logins_via_code = true

      [false, true].each do |password_reset|
        Jobs::SendEmailLoginCode.new.execute(
          to_address: user.email,
          code: "123456",
          password_reset: password_reset,
        )
      end

      expect(delivered_addresses).to eq(%w[critical.example.com critical.example.com])
      expect(delivered.map(&:subject)).to eq(
        %w[email_login_code_mailer password_reset_code_mailer].map do |template|
          I18n.t("#{template}.subject_template", code: "123456")
        end,
      )
    end

    it "routes invited-user password setup and admin confirmation through their own jobs" do
      admin_token = SecureRandom.hex
      Jobs::InvitePasswordInstructionsEmail.new.execute(username: user.username)
      Jobs::AdminConfirmationEmail.new.execute(
        to_address: user.email,
        target_email: "new-admin@example.com",
        target_username: "new_admin",
        token: admin_token,
      )

      expect(delivered_addresses).to eq(%w[critical.example.com critical.example.com])
      password_token = delivered.first.text_part.decoded[%r{/password-reset/([0-9a-f]+)}, 1]
      expect(
        EmailToken.confirmable(password_token, scope: EmailToken.scopes[:password_reset])&.user,
      ).to eq(user)
      expect(delivered.last.text_part.decoded).to include(admin_token)
      expect(EmailLog.order(:id).last(2).map(&:email_type)).to eq(
        %w[invite_password_instructions admin_confirmation_message],
      )
    end

    it "uses the verification recipient for an email-address change" do
      Jobs::CriticalUserEmail.new.execute(
        user_id: user.id,
        type: "confirm_new_email",
        email_token: "email-change-token",
        to_address: "new-address@example.com",
      )

      expect(delivered.size).to eq(1)
      expect(delivered.first.to).to eq(["new-address@example.com"])
      expect(delivered.first.text_part.decoded).to include("email-change-token")
      expect(delivered_addresses).to eq(["critical.example.com"])
    end

    it "leaves digests, ordinary, unknown, invite, moderation, and notice types on default SMTP" do
      %w[
        digest
        user_replied
        unknown_plugin_email
        invite
        signup_after_approval
        signup_after_reject
        suspicious_login
        notify_old_email
        notify_old_email_add
        account_exists
        account_associated
        account_second_factor_disabled
        account_silenced
        account_suspended
        account_deleted
      ].each do |type|
        message = TestMailer.send_test(user.email).message
        transport = message.delivery_method

        Email::Sender.new(message, type, user).send

        expect(message.delivery_method).to equal(transport)
        expect(message.delivery_method.settings).to include(default_settings)
      end
    end

    it "keeps the real approval welcome and address-change notices on default SMTP" do
      %w[signup_after_approval notify_old_email notify_old_email_add].each do |type|
        Jobs::CriticalUserEmail.new.execute(
          user_id: user.id,
          type: type,
          new_email: "new-address@example.com",
        )
      end

      expect(delivered_addresses).to eq(Array.new(3, default_settings[:address]))
    end

    [false, true].each do |code_mode|
      it "keeps real #{code_mode ? "code-mode" : "token-link"} invitations on default SMTP" do
        SiteSetting.allow_email_invites = true
        SiteSetting.enable_local_logins_via_code = code_mode
        invite = Fabricate(:invite)

        Jobs::InviteEmail.new.execute(invite_id: invite.id)

        expect(delivered.size).to eq(1)
        message = delivered.first
        expect(message.to).to eq([invite.email])
        expect(message.text_part.decoded).to include(invite.link(with_email_token: !code_mode))
        if code_mode
          expect(message.text_part.decoded).not_to include(invite.email_token)
        else
          expect(message.text_part.decoded).to include(invite.email_token)
        end
        expect(message.delivery_method.settings).to include(default_settings)
        expect(EmailLog.last.email_type).to eq("invite")
      end
    end

    it "uses independent relay defaults and retains transaction-response logging" do
      message = UserNotifications.forgot_password(user).message
      original_from = message.from
      original_reply_to = message.reply_to

      log = Email::Sender.new(message, :forgot_password, user).send

      expect(message.delivery_method.settings).to include(
        address: "critical.example.com",
        port: 25,
        domain: nil,
        user_name: nil,
        password: nil,
        authentication: nil,
        enable_starttls_auto: true,
        tls: nil,
        openssl_verify_mode: nil,
        open_timeout: 5.0,
        read_timeout: 30.0,
        return_response: true,
      )
      expect(message.from).to eq(original_from)
      expect(message.reply_to).to eq(original_reply_to)
      expect(log.smtp_transaction_response).to eq(smtp_response.message.chomp)
    end

    it "passes configured credentials, TLS, and timeouts to the individual transport" do
      global_setting :critical_smtp_port, 465
      global_setting :critical_smtp_domain, "critical-helo.example.com"
      global_setting :critical_smtp_user_name, "critical-user"
      global_setting :critical_smtp_password, "critical-password"
      global_setting :critical_smtp_authentication, "plain"
      global_setting :critical_smtp_force_tls, true
      global_setting :critical_smtp_openssl_verify_mode, "peer"
      global_setting :critical_smtp_open_timeout, "1.5"
      global_setting :critical_smtp_read_timeout, "9.5"
      message = UserNotifications.signup(user).message

      Email::Sender.new(message, :signup, user).send

      expect(message.delivery_method.settings).to include(
        address: "critical.example.com",
        port: 465,
        domain: "critical-helo.example.com",
        user_name: "critical-user",
        password: "critical-password",
        authentication: "plain",
        tls: true,
        enable_starttls_auto: false,
        openssl_verify_mode: "peer",
        open_timeout: 1.5,
        read_timeout: 9.5,
        return_response: true,
      )
    end

    it "routes interleaved messages individually without changing global settings" do
      global_settings = default_settings.deep_dup
      {
        signup: UserNotifications.signup(user).message,
        test_message: TestMailer.send_test(user.email).message,
        forgot_password: UserNotifications.forgot_password(user).message,
      }.each { |type, message| Email::Sender.new(message, type, user).send }

      expect(delivered_addresses).to eq(
        %w[critical.example.com default.example.com critical.example.com],
      )
      expect(ActionMailer::Base.smtp_settings).to eq(global_settings)
      expect(ActionMailer::Base.delivery_method).to eq(:smtp)
    end

    it "routes mailer subclasses that inherit the default SMTP configuration" do
      stub_const(Object, :CriticalSmtpTestMailer, Class.new(TestMailer)) do
        message = CriticalSmtpTestMailer.send_test(user.email).message

        Email::Sender.new(message, :signup, user).send

        expect(message.delivery_method.settings[:address]).to eq("critical.example.com")
      end
    end

    it "preserves SMTP transports that differ from the default" do
      stub_const(Object, :CriticalSmtpTestMailer, Class.new(TestMailer)) do
        CriticalSmtpTestMailer.smtp_settings = default_settings.merge(port: 2525)
        edited = UserNotifications.signup(user).message
        edited.delivery_method.settings[:password] = "per-message-password"

        [
          TestMailer.send_test(
            user.email,
            delivery_method_options: {
              address: "custom.example.com",
            },
          ).message,
          CriticalSmtpTestMailer.send_test(user.email).message,
          edited,
        ].each do |message|
          transport = message.delivery_method
          settings = transport.settings.deep_dup

          Email::Sender.new(message, :signup, user).send

          expect(message.delivery_method).to equal(transport)
          expect(transport.settings).to eq(settings)
        end
      end
    end

    it "preserves real group SMTP even for an included email type" do
      SiteSetting.enable_smtp = true
      group = Fabricate(:smtp_group)
      message = GroupSmtpMailer.send_mail(group, user.email, Fabricate(:post)).message
      transport = message.delivery_method

      log = Email::Sender.new(message, :signup, user).send

      expect(message.delivery_method).to equal(transport)
      expect(transport.settings).to include(
        address: group.smtp_server,
        user_name: group.email_username,
        password: group.email_password,
      )
      expect(log.smtp_group_id).to eq(group.id)
    end

    it "preserves test, file, sendmail, custom adapters, and SMTP subclasses" do
      custom_adapter =
        Class.new do
          attr_reader :settings

          def initialize(settings)
            @settings = settings
          end
        end

      [:test, :file, :sendmail, custom_adapter, Class.new(Mail::SMTP)].each do |adapter|
        message = UserNotifications.signup(user).message
        message.delivery_method(adapter, default_settings.merge(return_response: true))
        transport = message.delivery_method
        transport.stubs(:deliver!).returns(smtp_response)

        Email::Sender.new(message, :signup, user).send

        expect(message.delivery_method).to equal(transport)
      end
    end

    it "treats explicitly supplied settings identical to the defaults as default SMTP" do
      message = Mail::Message.new(to: user.email, body: "account mail")
      message.delivery_method(:smtp, default_settings)

      Email::Sender.new(message, :signup, user).send

      expect(delivered).to eq([message])
      expect(delivered_addresses).to eq(["critical.example.com"])
    end

    it "preserves local capture in the profile environment" do
      Rails.env.stubs(:profile?).returns(true)
      message = UserNotifications.signup(user).message
      transport = message.delivery_method

      Email::Sender.new(message, :signup, user).send

      expect(message.delivery_method).to equal(transport)
    end

    it "preserves local capture in development unless environment SMTP is enabled" do
      Rails.env.stubs(:development?).returns(true)
      local_settings = { address: "localhost", port: 1025 }
      ActionMailer::Base.smtp_settings = local_settings

      # use_smtp_environment_in_development is normally undefined in development.
      captured = UserNotifications.signup(user).message
      Email::Sender.new(captured, :signup, user).send

      expect(captured.delivery_method.settings).to include(local_settings)

      global_setting :use_smtp_environment_in_development, true
      routed = UserNotifications.signup(user).message
      Email::Sender.new(routed, :signup, user).send

      expect(routed.delivery_method.settings[:address]).to eq("critical.example.com")
    end

    it "adds provider metadata for the critical destination" do
      ActionMailer::Base.smtp_settings = default_settings.merge(address: "smtp.mandrillapp.com")

      {
        "in-v3.mailjet.com" => "X-MJ-CustomID",
        "smtp.mandrillapp.com" => "X-MC-Metadata",
        "smtp.sparkpostmail.com" => "X-MSYS-API",
      }.each do |address, header|
        global_setting :critical_smtp_address, address
        message = UserNotifications.signup(user).message

        Email::Sender.new(message, :signup, user).send

        expect(message.header[header].to_s).to include(message.message_id)
        expect(message.header["X-MC-Metadata"]).to be_nil unless header == "X-MC-Metadata"
      end
    end

    it "retains global-provider metadata for mail outside the critical route" do
      ActionMailer::Base.smtp_settings = default_settings.merge(address: "smtp.mandrillapp.com")
      message = TestMailer.send_test(user.email).message

      Email::Sender.new(message, :test_message, user).send

      expect(JSON.parse(message.header["X-MC-Metadata"].to_s)).to eq(
        "message_id" => message.message_id,
      )
    end

    it "allows a hook to replace the selected transport with a non-SMTP adapter" do
      handler = proc { |message, _type| message.delivery_method(:test) }
      DiscourseEvent.on(:before_email_send, &handler)
      message = UserNotifications.signup(user).message

      Email::Sender.new(message, :signup, user).send

      expect(ActionMailer::Base.deliveries).to include(message)
      expect(delivered).to be_empty
    ensure
      DiscourseEvent.off(:before_email_send, &handler)
    end

    [Net::SMTPFatalError, Net::SMTPSyntaxError, Net::SMTPServerBusy, IOError].each do |error_class|
      it "does not attempt a second route after #{error_class}" do
        attempts = []
        Mail::SMTP
          .any_instance
          .stubs(:deliver!)
          .with do |message|
            attempts << message.delivery_method.settings[:address]
            true
          end
          .raises(error_class.new("SMTP route failed"))
        message = UserNotifications.signup(user).message
        sender = Email::Sender.new(message, :signup, user)

        if [Net::SMTPFatalError, Net::SMTPSyntaxError].include?(error_class)
          result = sender.send
          expect(result).to be_a(SkippedEmailLog)
          expect(result.custom_reason).to include("SMTP route failed")
        else
          expect { sender.send }.to raise_error(error_class)
        end

        expect(attempts).to eq(["critical.example.com"])
        expect(EmailLog.where(email_type: "signup", user_id: user.id)).to be_empty
      end
    end
  end
end

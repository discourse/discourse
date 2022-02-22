# frozen_string_literal: true

require 'rails_helper'
require 'email/sender'

describe Email::Sender do
  before do
    SiteSetting.secure_media_allow_embed_images_in_emails = false
  end
  fab!(:post) { Fabricate(:post) }

  context "disable_emails is enabled" do
    fab!(:user) { Fabricate(:user) }
    fab!(:moderator) { Fabricate(:moderator) }

    context "disable_emails is enabled for everyone" do
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

    context "disable_emails is enabled for non-staff users" do
      before { SiteSetting.disable_emails = "non-staff" }

      it "doesn't deliver mail to normal user" do
        Mail::Message.any_instance.expects(:deliver_now).never
        message = Mail::Message.new(to: user.email, body: "hello")
        expect(Email::Sender.new(message, :hello).send).to eq(nil)
      end

      it "delivers mail to staff user" do
        Mail::Message.any_instance.expects(:deliver_now).once
        message = Mail::Message.new(to: moderator.email, body: "hello")
        Email::Sender.new(message, :hello).send
      end

      it "delivers mail to staff user when confirming new email if user is provided" do
        Mail::Message.any_instance.expects(:deliver_now).once
        Fabricate(:email_change_request, {
          user: moderator,
          new_email: "newemail@testmoderator.com",
          old_email: moderator.email,
          change_state: EmailChangeRequest.states[:authorizing_new]
        })
        message = Mail::Message.new(
          to: "newemail@testmoderator.com", body: "hello"
        )
        Email::Sender.new(message, :confirm_new_email, moderator).send
      end
    end
  end

  it "doesn't deliver mail when the message is of type NullMail" do
    Mail::Message.any_instance.expects(:deliver_now).never
    message = ActionMailer::Base::NullMail.new
    expect(Email::Sender.new(message, :hello).send).to eq(nil)
  end

  it "doesn't deliver mail when the message is nil" do
    Mail::Message.any_instance.expects(:deliver_now).never
    Email::Sender.new(nil, :hello).send
  end

  it "doesn't deliver when the to address is nil" do
    message = Mail::Message.new(body: 'hello')
    message.expects(:deliver_now).never
    Email::Sender.new(message, :hello).send
  end

  it "doesn't deliver when the to address uses the .invalid tld" do
    message = Mail::Message.new(body: 'hello', to: 'myemail@example.invalid')
    message.expects(:deliver_now).never
    expect { Email::Sender.new(message, :hello).send }.
      to change { SkippedEmailLog.where(reason_type: SkippedEmailLog.reason_types[:sender_message_to_invalid]).count }.by(1)
  end

  it "doesn't deliver when the body is nil" do
    message = Mail::Message.new(to: 'eviltrout@test.domain')
    message.expects(:deliver_now).never
    Email::Sender.new(message, :hello).send
  end

  context "host_for" do
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

  context 'with a valid message' do

    let(:reply_key) { "abcd" * 8 }

    let(:message) do
      message = Mail::Message.new(
        to: 'eviltrout@test.domain',
        body: '**hello**'
      )
      message.stubs(:deliver_now)
      message
    end

    let(:email_sender) { Email::Sender.new(message, :valid_type) }

    it 'calls deliver' do
      message.expects(:deliver_now).once
      email_sender.send
    end

    context "doesn't add return_path when no plus addressing" do
      before { SiteSetting.reply_by_email_address = '%{reply_key}@test.com' }

      it 'should not set the return_path' do
        email_sender.send
        expect(message.header[:return_path].to_s).to eq("")
      end
    end

    context "adds return_path with plus addressing" do
      before { SiteSetting.reply_by_email_address = 'replies+%{reply_key}@test.com' }

      it 'should set the return_path' do
        email_sender.send
        expect(message.header[:return_path].to_s).to eq("replies+verp-#{EmailLog.last.bounce_key}@test.com")
      end
    end

    context "adds a List-ID header to identify the forum" do
      fab!(:category) { Fabricate(:category, name: 'Name With Space') }
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:post) { Fabricate(:post, topic: topic) }

      before do
        message.header['X-Discourse-Post-Id']  = post.id
        message.header['X-Discourse-Topic-Id'] = topic.id
      end

      it 'should add the right header' do
        email_sender.send

        expect(message.header['List-ID']).to be_present
        expect(message.header['List-ID'].to_s).to match('name-with-space')
      end
    end

    context "adds a Message-ID header even when topic id is not present" do

      it 'should add the right header' do
        email_sender.send

        expect(message.header['Message-ID']).to be_present
      end
    end

    context "replaces reply_key in custom headers" do
      fab!(:user) { Fabricate(:user) }
      let(:email_sender) { Email::Sender.new(message, :valid_type, user) }
      let(:reply_key) { PostReplyKey.find_by!(post_id: post.id, user_id: user.id).reply_key }

      before do
        SiteSetting.reply_by_email_address = 'replies+%{reply_key}@test.com'
        SiteSetting.email_custom_headers = 'Auto-Submitted: auto-generated|Mail-Reply-To: sender-name+%{reply_key}@domain.net'

        message.header['X-Discourse-Post-Id'] = post.id
      end

      it 'replaces headers with reply_key if present' do
        message.header[Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER] = 'test-%{reply_key}@test.com'
        message.header['Reply-To'] = 'Test <test-%{reply_key}@test.com>'
        message.header['Auto-Submitted'] = 'auto-generated'
        message.header['Mail-Reply-To'] = 'sender-name+%{reply_key}@domain.net'

        email_sender.send

        expect(message.header['Reply-To'].to_s).to eq("Test <test-#{reply_key}@test.com>")
        expect(message.header['Auto-Submitted'].to_s).to eq('auto-generated')
        expect(message.header['Mail-Reply-To'].to_s).to eq("sender-name+#{reply_key}@domain.net")
      end

      it 'removes headers with reply_key if absent' do
        message.header['Auto-Submitted'] = 'auto-generated'
        message.header['Mail-Reply-To'] = 'sender-name+%{reply_key}@domain.net'

        email_sender.send

        expect(message.header['Reply-To'].to_s).to eq('')
        expect(message.header['Auto-Submitted'].to_s). to eq('auto-generated')
        expect(message.header['Mail-Reply-To'].to_s).to eq('')
      end
    end

    context "adds Precedence header" do
      fab!(:topic) { Fabricate(:topic) }
      fab!(:post) { Fabricate(:post, topic: topic) }

      before do
        message.header['X-Discourse-Post-Id']  = post.id
        message.header['X-Discourse-Topic-Id'] = topic.id
      end

      it 'should add the right header' do
        email_sender.send
        expect(message.header['Precedence']).to be_present
      end
    end

    context "removes custom Discourse headers from topic notification mails" do
      fab!(:topic) { Fabricate(:topic) }
      fab!(:post) { Fabricate(:post, topic: topic) }

      before do
        message.header['X-Discourse-Post-Id']  = post.id
        message.header['X-Discourse-Topic-Id'] = topic.id
      end

      it 'should remove the right headers' do
        email_sender.send
        expect(message.header['X-Discourse-Topic-Id']).not_to be_present
        expect(message.header['X-Discourse-Post-Id']).not_to be_present
        expect(message.header['X-Discourse-Reply-Key']).not_to be_present
      end
    end

    context "removes custom Discourse headers from digest/registration/other mails" do
      it 'should remove the right headers' do
        email_sender.send
        expect(message.header['X-Discourse-Topic-Id']).not_to be_present
        expect(message.header['X-Discourse-Post-Id']).not_to be_present
        expect(message.header['X-Discourse-Reply-Key']).not_to be_present
      end
    end

    context "email threading" do
      let(:random_message_id_suffix) { "5f1330cfd941f323d7f99b9e" }
      fab!(:topic) { Fabricate(:topic) }

      fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
      fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }
      fab!(:post_3) { Fabricate(:post, topic: topic, post_number: 3) }
      fab!(:post_4) { Fabricate(:post, topic: topic, post_number: 4) }

      let!(:post_reply_1_4) { PostReply.create(post: post_1, reply: post_4) }
      let!(:post_reply_2_4) { PostReply.create(post: post_2, reply: post_4) }
      let!(:post_reply_3_4) { PostReply.create(post: post_3, reply: post_4) }

      before do
        message.header['X-Discourse-Topic-Id'] = topic.id
        Email::MessageIdService.stubs(:random_suffix).returns(random_message_id_suffix)
      end

      it "doesn't set the 'In-Reply-To' header but does set the 'References' header on the first post" do
        message.header['X-Discourse-Post-Id'] = post_1.id

        email_sender.send

        expect(message.header['Message-Id'].to_s).to eq("<topic/#{topic.id}.#{random_message_id_suffix}@test.localhost>")
        expect(message.header['In-Reply-To'].to_s).to be_blank
        expect(message.header['References'].to_s).to eq("<topic/#{topic.id}@test.localhost>")
      end

      it "sets the 'References' header with the incoming email Message-ID if it exists on the first post" do
        incoming = Fabricate(
          :incoming_email,
          topic: topic,
          post: post_1,
          message_id: "blah1234@someemailprovider.com",
          created_via: IncomingEmail.created_via_types[:handle_mail]
        )
        message.header['X-Discourse-Post-Id'] = post_1.id

        email_sender.send

        expect(message.header['Message-Id'].to_s).to eq("<topic/#{topic.id}.#{random_message_id_suffix}@test.localhost>")
        expect(message.header['In-Reply-To'].to_s).to be_blank
        expect(message.header['References'].to_s).to eq("<blah1234@someemailprovider.com>")
      end

      it "sets the 'In-Reply-To' header to the topic canonical reference by default" do
        message.header['X-Discourse-Post-Id'] = post_2.id

        email_sender.send

        expect(message.header['Message-Id'].to_s).to eq("<topic/#{topic.id}/#{post_2.id}.#{random_message_id_suffix}@test.localhost>")
        expect(message.header['In-Reply-To'].to_s).to eq("<topic/#{topic.id}@test.localhost>")
      end

      it "sets the 'In-Reply-To' header to the newest replied post" do
        message.header['X-Discourse-Post-Id'] = post_4.id

        email_sender.send

        expect(message.header['Message-Id'].to_s).to eq("<topic/#{topic.id}/#{post_4.id}.#{random_message_id_suffix}@test.localhost>")
        expect(message.header['In-Reply-To'].to_s).to eq("<topic/#{topic.id}/#{post_3.id}.#{random_message_id_suffix}@test.localhost>")
      end

      it "sets the 'References' header to the topic canonical reference and all replied posts" do
        message.header['X-Discourse-Post-Id'] = post_4.id

        email_sender.send

        references = [
          "<topic/#{topic.id}@test.localhost>",
          "<topic/#{topic.id}/#{post_3.id}.#{random_message_id_suffix}@test.localhost>",
          "<topic/#{topic.id}/#{post_2.id}.#{random_message_id_suffix}@test.localhost>",
        ]

        expect(message.header['References'].to_s).to eq(references.join(" "))
      end

      it "uses the incoming_email message_id when available, but always uses a random message-id" do
        topic_incoming_email  = IncomingEmail.create(
          topic: topic, post: post_1, message_id: "foo@bar", created_via: IncomingEmail.created_via_types[:handle_mail]
        )
        post_2_incoming_email = IncomingEmail.create(topic: topic, post: post_2, message_id: "bar@foo")
        post_4_incoming_email = IncomingEmail.create(topic: topic, post: post_4, message_id: "wat@wat")

        message.header['X-Discourse-Post-Id'] = post_4.id

        email_sender.send

        expect(message.header['Message-Id'].to_s).to eq("<topic/#{topic.id}/#{post_4.id}.5f1330cfd941f323d7f99b9e@test.localhost>")

        references = [
          "<#{topic_incoming_email.message_id}>",
          "<topic/#{topic.id}/#{post_3.id}.#{random_message_id_suffix}@test.localhost>",
          "<#{post_2_incoming_email.message_id}>",
        ]

        expect(message.header['References'].to_s).to eq(references.join(" "))
      end

    end

    context "merges custom mandrill header" do
      before do
        ActionMailer::Base.smtp_settings[:address] = "smtp.mandrillapp.com"
        message.header['X-MC-Metadata'] = { foo: "bar" }.to_json
      end

      it 'should set the right header' do
        email_sender.send
        expect(message.header['X-MC-Metadata'].to_s).to match(message.message_id)
      end
    end

    context "merges custom sparkpost header" do
      before do
        ActionMailer::Base.smtp_settings[:address] = "smtp.sparkpostmail.com"
        message.header['X-MSYS-API'] = { foo: "bar" }.to_json
      end

      it 'should set the right header' do
        email_sender.send
        expect(message.header['X-MSYS-API'].to_s).to match(message.message_id)
      end
    end

    context 'email logs' do
      let(:email_log) { EmailLog.last }

      it 'should create the right log' do
        expect do
          email_sender.send
        end.to_not change { PostReplyKey.count }

        expect(email_log).to be_present
        expect(email_log.email_type).to eq('valid_type')
        expect(email_log.to_address).to eq('eviltrout@test.domain')
        expect(email_log.user_id).to be_blank
        expect(email_log.raw).to eq(nil)
      end

      context 'when the email is sent using group SMTP credentials' do
        let(:reply) { Fabricate(:post, topic: post.topic, reply_to_user: post.user, reply_to_post_number: post.post_number) }
        let(:notification) { Fabricate(:posted_notification, user: post.user, post: reply) }
        let(:message) do
          GroupSmtpMailer.send_mail(
            group,
            post.user.email,
            post
          )
        end
        let(:group) { Fabricate(:smtp_group) }

        before do
          SiteSetting.enable_smtp = true
        end

        it 'adds the group id and raw content to the email log' do
          TopicAllowedGroup.create(topic: post.topic, group: group)

          email_sender.send

          expect(email_log).to be_present
          expect(email_log.email_type).to eq('valid_type')
          expect(email_log.to_address).to eq(post.user.email)
          expect(email_log.user_id).to be_blank
          expect(email_log.smtp_group_id).to eq(group.id)
          expect(email_log.raw).to include("Hello world")
        end

        it "does not add any of the mailing list headers" do
          TopicAllowedGroup.create(topic: post.topic, group: group)
          email_sender.send

          expect(message.header['List-ID']).to eq(nil)
          expect(message.header['List-Archive']).to eq(nil)
          expect(message.header['Precedence']).to eq(nil)
          expect(message.header['List-Unsubscribe']).to eq(nil)
        end

        it "removes the Auto-Submitted header" do
          TopicAllowedGroup.create!(topic: post.topic, group: group)
          email_sender.send

          expect(message.header['Auto-Submitted']).to eq(nil)
        end
      end
    end

    context "email log with a post id and topic id" do
      let(:topic) { post.topic }

      before do
        message.header['X-Discourse-Post-Id'] = post.id
        message.header['X-Discourse-Topic-Id'] = topic.id
      end

      let(:email_log) { EmailLog.last }

      it 'should create the right log' do
        email_sender.send
        expect(email_log.post_id).to eq(post.id)
        expect(email_log.topic_id).to eq(topic.id)
        expect(email_log.topic.id).to eq(topic.id)
      end
    end

    context 'email parts' do
      it 'should contain the right message' do
        email_sender.send

        expect(message).to be_multipart
        expect(message.text_part.content_type).to eq('text/plain; charset=UTF-8')
        expect(message.html_part.content_type).to eq('text/html; charset=UTF-8')
        expect(message.html_part.body.to_s).to match("<p><strong>hello</strong></p>")
      end
    end
  end

  context "with attachments" do
    fab!(:small_pdf) do
      SiteSetting.authorized_extensions = 'pdf'
      UploadCreator.new(file_from_fixtures("small.pdf", "pdf"), "small.pdf")
        .create_for(Discourse.system_user.id)
    end
    fab!(:large_pdf) do
      SiteSetting.authorized_extensions = 'pdf'
      UploadCreator.new(file_from_fixtures("large.pdf", "pdf"), "large.pdf")
        .create_for(Discourse.system_user.id)
    end
    fab!(:csv_file) do
      SiteSetting.authorized_extensions = 'csv'
      UploadCreator.new(file_from_fixtures("words.csv", "csv"), "words.csv")
        .create_for(Discourse.system_user.id)
    end
    fab!(:image) do
      SiteSetting.authorized_extensions = 'png'
      UploadCreator.new(file_from_fixtures("logo.png", "images"), "logo.png")
        .create_for(Discourse.system_user.id)
    end
    fab!(:post) { Fabricate(:post) }
    fab!(:reply) do
      raw = <<~RAW
        Hello world! It’s a great day!
        #{UploadMarkdown.new(small_pdf).attachment_markdown}
        #{UploadMarkdown.new(large_pdf).attachment_markdown}
        #{UploadMarkdown.new(image).image_markdown}
        #{UploadMarkdown.new(csv_file).attachment_markdown}
      RAW
      reply = Fabricate(:post, raw: raw, topic: post.topic, user: Fabricate(:user))
      reply.link_post_uploads
      reply
    end
    fab!(:notification) { Fabricate(:posted_notification, user: post.user, post: reply) }
    let(:message) do
      UserNotifications.user_posted(
        post.user,
        post: reply,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      )
    end

    it "adds only non-image uploads as attachments to the email" do
      SiteSetting.email_total_attachment_size_limit_kb = 10_000
      Email::Sender.new(message, :valid_type).send

      expect(message.attachments.length).to eq(3)
      expect(message.attachments.map(&:filename))
        .to contain_exactly(*[small_pdf, large_pdf, csv_file].map(&:original_filename))
    end

    context "when secure media enabled" do
      before do
        setup_s3
        store = stub_s3_store

        SiteSetting.secure_media = true
        SiteSetting.login_required = true
        SiteSetting.email_total_attachment_size_limit_kb = 14_000
        SiteSetting.secure_media_max_email_embed_image_size_kb = 5_000

        Jobs.run_immediately!
        Jobs::PullHotlinkedImages.any_instance.expects(:execute)
        FileStore::S3Store.any_instance.expects(:has_been_uploaded?).returns(true).at_least_once
        CookedPostProcessor.any_instance.stubs(:get_size).returns([244, 66])

        @secure_image_file = file_from_fixtures("logo.png", "images")
        @secure_image = UploadCreator.new(@secure_image_file, "logo.png")
          .create_for(Discourse.system_user.id)
        @secure_image.update_secure_status(override: true)
        @secure_image.update(access_control_post_id: reply.id)
        reply.update(raw: reply.raw + "\n" + "#{UploadMarkdown.new(@secure_image).image_markdown}")
        reply.rebake!
      end

      it "does not attach images when embedding them is not allowed" do
        Email::Sender.new(message, :valid_type).send
        expect(message.attachments.length).to eq(3)
      end

      context "when embedding secure images in email is allowed" do
        before do
          SiteSetting.secure_media_allow_embed_images_in_emails = true
        end

        it "can inline images with duplicate names" do
          @secure_image_2 = UploadCreator.new(file_from_fixtures("logo-dev.png", "images"), "logo.png").create_for(Discourse.system_user.id)
          @secure_image_2.update_secure_status(override: true)
          @secure_image_2.update(access_control_post_id: reply.id)

          Jobs::PullHotlinkedImages.any_instance.expects(:execute)
          reply.update(raw: "#{UploadMarkdown.new(@secure_image).image_markdown}\n#{UploadMarkdown.new(@secure_image_2).image_markdown}")
          reply.rebake!

          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.size).to eq(2)
          expect(message.to_s.scan(/cid:[\w\-@.]+/).length).to eq(2)
          expect(message.to_s.scan(/cid:[\w\-@.]+/).uniq.length).to eq(2)
        end

        it "does not attach images that are not marked as secure" do
          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.length).to eq(4)
        end

        it "does not embed images that are too big" do
          SiteSetting.secure_media_max_email_embed_image_size_kb = 1
          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.length).to eq(3)
        end

        it "uses the email styles to inline secure images and attaches the secure image upload to the email" do
          Email::Sender.new(message, :valid_type).send
          expect(message.attachments.length).to eq(4)
          expect(message.attachments.map(&:filename))
            .to contain_exactly(*[small_pdf, large_pdf, csv_file, @secure_image].map(&:original_filename))
          expect(message.attachments["logo.png"].body.raw_source.force_encoding("UTF-8")).to eq(File.read(@secure_image_file))
          expect(message.html_part.body).to include("cid:")
          expect(message.html_part.body).to include("embedded-secure-image")
          expect(message.attachments.length).to eq(4)
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
            optimized.update(url: Discourse.store.absolute_base_url + '/' + url)
            Discourse.store.cache_file(optimized_image_file, File.basename("#{optimized.sha1}.png"))
          end

          it "uses the email styles and the optimized image to inline secure images and attaches the secure image upload to the email" do
            Email::Sender.new(message, :valid_type).send
            expect(message.attachments.length).to eq(4)
            expect(message.attachments.map(&:filename))
              .to contain_exactly(*[small_pdf, large_pdf, csv_file, @secure_image].map(&:original_filename))
            expect(message.attachments["logo.png"].body.raw_source.force_encoding("UTF-8")).to eq(File.read(optimized_image_file))
            expect(message.html_part.body).to include("cid:")
            expect(message.html_part.body).to include("embedded-secure-image")
          end

          it "uses the optimized image size in the max size limit calculation, not the original image size" do
            SiteSetting.email_total_attachment_size_limit_kb = 45
            Email::Sender.new(message, :valid_type).send
            expect(message.attachments.length).to eq(4)
            expect(message.attachments["logo.png"].body.raw_source.force_encoding("UTF-8")).to eq(File.read(optimized_image_file))
          end
        end
      end
    end

    it "adds only non-image uploads as attachments to the email and leaves the image intact with original source" do
      SiteSetting.email_total_attachment_size_limit_kb = 10_000
      Email::Sender.new(message, :valid_type).send

      expect(message.attachments.length).to eq(3)
      expect(message.attachments.map(&:filename))
        .to contain_exactly(*[small_pdf, large_pdf, csv_file].map(&:original_filename))
      expect(message.html_part.body).to include("<img src=\"#{Discourse.base_url}#{image.url}\"")
    end

    it "respects the size limit and attaches only files that fit into the max email size" do
      SiteSetting.email_total_attachment_size_limit_kb = 40
      Email::Sender.new(message, :valid_type).send

      expect(message.attachments.length).to eq(2)
      expect(message.attachments.map(&:filename))
        .to contain_exactly(*[small_pdf, csv_file].map(&:original_filename))
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

  context 'with a deleted post' do

    it 'should skip sending the email' do
      post = Fabricate(:post, deleted_at: 1.day.ago)

      message = Mail::Message.new to: 'disc@ourse.org', body: 'some content'
      message.header['X-Discourse-Post-Id'] = post.id
      message.header['X-Discourse-Topic-Id'] = post.topic_id
      message.expects(:deliver_now).never

      email_sender = Email::Sender.new(message, :valid_type)
      expect { email_sender.send }.to change { SkippedEmailLog.count }

      log = SkippedEmailLog.last
      expect(log.reason_type).to eq(SkippedEmailLog.reason_types[:sender_post_deleted])
    end

  end

  context 'with a deleted topic' do

    it 'should skip sending the email' do
      post = Fabricate(:post, topic: Fabricate(:topic, deleted_at: 1.day.ago))

      message = Mail::Message.new to: 'disc@ourse.org', body: 'some content'
      message.header['X-Discourse-Post-Id'] = post.id
      message.header['X-Discourse-Topic-Id'] = post.topic_id
      message.expects(:deliver_now).never

      email_sender = Email::Sender.new(message, :valid_type)
      expect { email_sender.send }.to change { SkippedEmailLog.count }

      log = SkippedEmailLog.last
      expect(log.reason_type).to eq(SkippedEmailLog.reason_types[:sender_topic_deleted])
    end

  end

  context 'with a user' do
    let(:message) do
      message = Mail::Message.new to: 'eviltrout@test.domain', body: 'test body'
      message.stubs(:deliver_now)
      message
    end

    fab!(:user) { Fabricate(:user) }
    let(:email_sender) { Email::Sender.new(message, :valid_type, user) }

    before do
      email_sender.send
      @email_log = EmailLog.last
    end

    it 'should have the current user_id' do
      expect(@email_log.user_id).to eq(user.id)
    end

    describe "post reply keys" do
      fab!(:post) { Fabricate(:post) }

      before do
        message.header['X-Discourse-Post-Id'] = post.id
        message.header['Reply-To'] = "test-%{reply_key}@test.com"
      end

      describe 'when allow reply by email header is not present' do
        it 'should not create a post reply key' do
          expect { email_sender.send }.to_not change { PostReplyKey.count }
        end
      end

      describe 'when allow reply by email header is present' do
        let(:header) { Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER }

        before do
          message.header[header] = "test-%{reply_key}@test.com"
        end

        it 'should create a post reply key' do
          expect { email_sender.send }.to change { PostReplyKey.count }.by(1)
          post_reply_key = PostReplyKey.last

          expect(message.header['Reply-To'].value).to eq(
            "test-#{post_reply_key.reply_key}@test.com"
          )

          expect(message.header[header]).to eq(nil)
          expect(post_reply_key.user_id).to eq(user.id)
          expect(post_reply_key.post_id).to eq(post.id)
          expect { email_sender.send }.to change { PostReplyKey.count }.by(0)
        end
      end
    end
  end

  context "with cc addresses" do
    let(:message) do
      message = Mail::Message.new to: 'eviltrout@test.domain', body: 'test body', cc: 'someguy@test.com;otherguy@xyz.com'
      message.stubs(:deliver_now)
      message
    end

    fab!(:user) { Fabricate(:user) }
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
end

# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'email/receiver'

describe Email::Receiver do

  before do
    SiteSetting.reply_by_email_address = "reply+%{reply_key}@appmail.adventuretime.ooo"
    SiteSetting.email_in = false
    SiteSetting.title = "Discourse"
  end

  describe 'parse_body' do
    def test_parse_body(mail_string)
      Email::Receiver.new(nil).parse_body(Mail::Message.new mail_string)
    end

    it "raises EmptyEmailError if the message is blank" do
      expect { test_parse_body("") }.to raise_error(Email::Receiver::EmptyEmailError)
    end

    it "raises EmptyEmailError if the message is not an email" do
      expect { test_parse_body("asdf" * 30) }.to raise_error(Email::Receiver::EmptyEmailError)
    end

    it "raises EmptyEmailError if there is no reply content" do
      expect { test_parse_body(fixture_file("emails/no_content_reply.eml")) }.to raise_error(Email::Receiver::EmptyEmailError)
    end

    skip "raises EmailUnparsableError if the headers are corrupted" do
      expect { ; }.to raise_error(Email::Receiver::EmailUnparsableError)
    end

    it "can parse the html section" do
      expect(test_parse_body(fixture_file("emails/html_only.eml"))).to eq("The EC2 instance - I've seen that there tends to be odd and " +
          "unrecommended settings on the Bitnami installs that I've checked out.")
    end

    it "supports a Dutch reply" do
      expect(test_parse_body(fixture_file("emails/dutch.eml"))).to eq("Dit is een antwoord in het Nederlands.")
    end

    it "supports a Hebrew reply" do
      I18n.expects(:t).with('user_notifications.previous_discussion').returns('כלטוב')

      # The force_encoding call is only needed for the test - it is passed on fine to the cooked post
      expect(test_parse_body(fixture_file("emails/hebrew.eml"))).to eq("שלום")
    end

    it "supports a BIG5-encoded reply" do
      I18n.expects(:t).with('user_notifications.previous_discussion').returns('媽！我上電視了！')

      # The force_encoding call is only needed for the test - it is passed on fine to the cooked post
      expect(test_parse_body(fixture_file("emails/big5.eml"))).to eq("媽！我上電視了！")
    end

    it "removes 'via' lines if they match the site title" do
      SiteSetting.title = "Discourse"

      expect(test_parse_body(fixture_file("emails/via_line.eml"))).to eq("Hello this email has content!")
    end

    it "removes an 'on date wrote' quoting line" do
      expect(test_parse_body(fixture_file("emails/on_wrote.eml"))).to eq("Sure, all you need to do is frobnicate the foobar and you'll be all set!")
    end

    it "removes the 'Previous Discussion' marker" do
      expect(test_parse_body(fixture_file("emails/previous.eml"))).to eq("This will not include the previous discussion that is present in this email.")
    end

    it "handles multiple paragraphs" do
      expect(test_parse_body(fixture_file("emails/paragraphs.eml"))).
          to eq(
"Is there any reason the *old* candy can't be be kept in silos while the new candy
is imported into *new* silos?

The thing about candy is it stays delicious for a long time -- we can just keep
it there without worrying about it too much, imo.

Thanks for listening."
      )
    end

    it "handles multiple paragraphs when parsing html" do
      expect(test_parse_body(fixture_file("emails/html_paragraphs.eml"))).
          to eq(
"Awesome!

Pleasure to have you here!

:boom:"
      )
    end

    it "handles newlines" do
      expect(test_parse_body(fixture_file("emails/newlines.eml"))).
          to eq(
"This is my reply.
It is my best reply.
It will also be my *only* reply."
      )
    end

    it "handles inline reply" do
      expect(test_parse_body(fixture_file("emails/inline_reply.eml"))).
          to eq(
"On Wed, Oct 8, 2014 at 11:12 AM, techAPJ <info@unconfigured.discourse.org> wrote:

>     techAPJ <https://meta.discourse.org/users/techapj>
> November 28
>
> Test reply.
>
> First paragraph.
>
> Second paragraph.
>
> To respond, reply to this email or visit
> https://meta.discourse.org/t/testing-default-email-replies/22638/3 in
> your browser.
>  ------------------------------
> Previous Replies    codinghorror
> <https://meta.discourse.org/users/codinghorror>
> November 28
>
> We're testing the latest GitHub email processing library which we are
> integrating now.
>
> https://github.com/github/email_reply_parser
>
> Go ahead and reply to this topic and I'll reply from various email clients
> for testing.
>   ------------------------------
>
> To respond, reply to this email or visit
> https://meta.discourse.org/t/testing-default-email-replies/22638/3 in
> your browser.
>
> To unsubscribe from these emails, visit your user preferences
> <https://meta.discourse.org/my/preferences>.
>

The quick brown fox jumps over the lazy dog. The quick brown fox jumps over
the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown
fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.
The quick brown fox jumps over the lazy dog. The quick brown fox jumps over
the lazy dog. The quick brown fox jumps over the lazy dog."
      )
    end

    it "should not include previous replies" do
      expect(test_parse_body(fixture_file("emails/previous_replies.eml"))).not_to match /Previous Replies/
    end

    it "strips iPhone signature" do
      expect(test_parse_body(fixture_file("emails/iphone_signature.eml"))).not_to match /Sent from my iPhone/
    end

    it "properly renders email reply from gmail web client" do
      expect(test_parse_body(fixture_file("emails/gmail_web.eml"))).
          to eq(
"### This is a reply from standard GMail in Google Chrome.

The quick brown fox jumps over the lazy dog. The quick brown fox jumps over
the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown
fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.
The quick brown fox jumps over the lazy dog. The quick brown fox jumps over
the lazy dog. The quick brown fox jumps over the lazy dog.

Here's some **bold** text in Markdown.

Here's a link http://example.com"
      )
    end

    it "properly renders email reply from iOS default mail client" do
      expect(test_parse_body(fixture_file("emails/ios_default.eml"))).
          to eq(
"### this is a reply from iOS default mail

The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.

Here's some **bold** markdown text.

Here's a link http://example.com"
      )
    end

    it "properly renders email reply from Android 5 gmail client" do
      expect(test_parse_body(fixture_file("emails/android_gmail.eml"))).
          to eq(
"### this is a reply from Android 5 gmail

The quick brown fox jumps over the lazy dog. The quick brown fox jumps over
the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown
fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.
The quick brown fox jumps over the lazy dog.

This is **bold** in Markdown.

This is a link to http://example.com"
      )
    end

    it "properly renders email reply from Windows 8.1 Metro default mail client" do
      expect(test_parse_body(fixture_file("emails/windows_8_metro.eml"))).
          to eq(
"### reply from default mail client in Windows 8.1 Metro


The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.


This is a **bold** word in Markdown


This is a link http://example.com"
      )
    end

    it "properly renders email reply from MS Outlook client" do
      expect(test_parse_body(fixture_file("emails/outlook.eml"))).to eq("Microsoft Outlook 2010")
    end

    it "converts back to UTF-8 at the end" do
      result = test_parse_body(fixture_file("emails/big5.eml"))
      expect(result.encoding).to eq(Encoding::UTF_8)

      # should not throw
      TextCleaner.normalize_whitespaces(
          test_parse_body(fixture_file("emails/big5.eml"))
      )
    end
  end

  describe "posting replies" do
    let(:reply_key) { raise "Override this in a lower describe block" }
    let(:email_raw) { raise "Override this in a lower describe block" }
    # ----
    let(:receiver) { Email::Receiver.new(email_raw) }
    let(:post) { create_post }
    let(:topic) { post.topic }
    let(:posting_user) { post.user }
    let(:replying_user_email) { 'jake@adventuretime.ooo' }
    let(:replying_user) { Fabricate(:user, email: replying_user_email, trust_level: 2)}
    let(:email_log) { EmailLog.new(reply_key: reply_key,
                                   post: post,
                                   post_id: post.id,
                                   topic_id: post.topic_id,
                                   email_type: 'user_posted',
                                   user: replying_user,
                                   user_id: replying_user.id,
                                   to_address: replying_user_email
    ) }

    before do
      email_log.save
    end

    # === Success Posting ===

    describe "valid_reply.eml" do
      let!(:reply_key) { '59d8df8370b7e95c5a49fbf86aeb2c93' }
      let!(:email_raw) { fixture_file("emails/valid_reply.eml") }

      it "creates a post with the correct content" do
        start_count = topic.posts.count

        receiver.process

        expect(topic.posts.count).to eq(start_count + 1)
        created_post = topic.posts.last
        expect(created_post.via_email).to eq(true)
        expect(created_post.raw_email).to eq(fixture_file("emails/valid_reply.eml"))
        expect(created_post.cooked.strip).to eq(fixture_file("emails/valid_reply.cooked").strip)
      end
    end

    describe "paragraphs.eml" do
      let!(:reply_key) { '59d8df8370b7e95c5a49fbf86aeb2c93' }
      let!(:email_raw) { fixture_file("emails/paragraphs.eml") }

      it "cooks multiple paragraphs with traditional Markdown linebreaks" do
        start_count = topic.posts.count

        receiver.process

        expect(topic.posts.count).to eq(start_count + 1)
        expect(topic.posts.last.cooked.strip).to eq(fixture_file("emails/paragraphs.cooked").strip)
        expect(topic.posts.last.cooked).not_to match /<br/
      end
    end

    describe "attachment.eml" do
      let!(:reply_key) { '636ca428858779856c226bb145ef4fad' }
      let!(:email_raw) {
        fixture_file("emails/attachment.eml")
        .gsub("TO", "reply+#{reply_key}@appmail.adventuretime.ooo")
        .gsub("FROM", replying_user_email)
      }

      let(:upload_sha) { '04df605be528d03876685c52166d4b063aabb78a' }

      it "creates a post with an attachment" do
        Upload.stubs(:fix_image_orientation)
        ImageOptim.any_instance.stubs(:optimize_image!)

        start_count = topic.posts.count
        Upload.find_by(sha1: upload_sha).try(:destroy)

        receiver.process

        expect(topic.posts.count).to eq(start_count + 1)
        expect(topic.posts.last.cooked).to match /<img src=['"](\/uploads\/default\/original\/.+\.png)['"] width=['"]289['"] height=['"]126['"]>/
        expect(Upload.find_by(sha1: upload_sha)).not_to eq(nil)
      end

    end

    # === Failure Conditions ===

    describe "too_short.eml" do
      let!(:reply_key) { '636ca428858779856c226bb145ef4fad' }
      let!(:email_raw) {
        fixture_file("emails/too_short.eml")
        .gsub("TO", "reply+#{reply_key}@appmail.adventuretime.ooo")
        .gsub("FROM", replying_user_email)
        .gsub("SUBJECT", "re: [Discourse Meta] eviltrout posted in 'Adventure Time Sux'")
      }

      it "raises an InvalidPost error" do
        SiteSetting.min_post_length = 5
        expect { receiver.process }.to raise_error(Email::Receiver::InvalidPost)
      end
    end

    describe "too_many_mentions.eml" do
      let!(:reply_key) { '636ca428858779856c226bb145ef4fad' }
      let!(:email_raw) { fixture_file("emails/too_many_mentions.eml") }

      it "raises an InvalidPost error" do
        SiteSetting.max_mentions_per_post = 10
        (1..11).each do |i|
          Fabricate(:user, username: "user#{i}").save
        end

        expect { receiver.process }.to raise_error(Email::Receiver::InvalidPost)
      end
    end

    describe "auto response email replies should not be accepted" do
      let!(:reply_key) { '636ca428858779856c226bb145ef4fad' }
      let!(:email_raw) { fixture_file("emails/auto_reply.eml") }
      it "raises a AutoGeneratedEmailError" do
        expect { receiver.process }.to raise_error(Email::Receiver::AutoGeneratedEmailError)
      end
    end

  end

  describe "posting reply to a closed topic" do
    let(:reply_key) { raise "Override this in a lower describe block" }
    let(:email_raw) { raise "Override this in a lower describe block" }
    let(:receiver) { Email::Receiver.new(email_raw) }
    let(:topic) { Fabricate(:topic, closed: true) }
    let(:post) { Fabricate(:post, topic: topic, post_number: 1) }
    let(:replying_user_email) { 'jake@adventuretime.ooo' }
    let(:replying_user) { Fabricate(:user, email: replying_user_email, trust_level: 2) }
    let(:email_log) { EmailLog.new(reply_key: reply_key,
                                   post: post,
                                   post_id: post.id,
                                   topic_id: topic.id,
                                   email_type: 'user_posted',
                                   user: replying_user,
                                   user_id: replying_user.id,
                                   to_address: replying_user_email
    ) }

    before do
      email_log.save
    end

    describe "should not create post" do
      let!(:reply_key) { '59d8df8370b7e95c5a49fbf86aeb2c93' }
      let!(:email_raw) { fixture_file("emails/valid_reply.eml") }
      it "raises a TopicClosedError" do
        expect { receiver.process }.to raise_error(Email::Receiver::TopicClosedError)
      end
    end
  end

  describe "posting reply to a deleted topic" do
    let(:reply_key) { raise "Override this in a lower describe block" }
    let(:email_raw) { raise "Override this in a lower describe block" }
    let(:receiver) { Email::Receiver.new(email_raw) }
    let(:deleted_topic) { Fabricate(:deleted_topic) }
    let(:post) { Fabricate(:post, topic: deleted_topic, post_number: 1) }
    let(:replying_user_email) { 'jake@adventuretime.ooo' }
    let(:replying_user) { Fabricate(:user, email: replying_user_email, trust_level: 2) }
    let(:email_log) { EmailLog.new(reply_key: reply_key,
                                   post: post,
                                   post_id: post.id,
                                   topic_id: deleted_topic.id,
                                   email_type: 'user_posted',
                                   user: replying_user,
                                   user_id: replying_user.id,
                                   to_address: replying_user_email
    ) }

    before do
      email_log.save
    end

    describe "should not create post" do
      let!(:reply_key) { '59d8df8370b7e95c5a49fbf86aeb2c93' }
      let!(:email_raw) { fixture_file("emails/valid_reply.eml") }
      it "raises a TopicNotFoundError" do
        expect { receiver.process }.to raise_error(Email::Receiver::TopicNotFoundError)
      end
    end
  end

  describe "posting a new topic" do
    let(:category_destination) { raise "Override this in a lower describe block" }
    let(:email_raw) { raise "Override this in a lower describe block" }
    let(:allow_strangers) { false }
    # ----
    let(:receiver) { Email::Receiver.new(email_raw) }
    let(:user_email) { 'jake@adventuretime.ooo' }
    let(:user) { Fabricate(:user, email: user_email, trust_level: 2)}
    let(:category) { Fabricate(:category, email_in: category_destination, email_in_allow_strangers: allow_strangers) }

    before do
      SiteSetting.email_in = true
      user.save
      category.save
    end

    describe "too_short.eml" do
      let!(:category_destination) { 'incoming+amazing@appmail.adventuretime.ooo' }
      let(:email_raw) {
        fixture_file("emails/too_short.eml")
        .gsub("TO", category_destination)
        .gsub("FROM", user_email)
        .gsub("SUBJECT", "A long subject that passes the checks")
      }

      it "does not create a topic if the post fails" do
        before_topic_count = Topic.count

        expect { receiver.process }.to raise_error(Email::Receiver::InvalidPost)

        expect(Topic.count).to eq(before_topic_count)
      end

    end

  end

  def fill_email(mail, from, to, body = nil, subject = nil)
    result = mail.gsub("FROM", from).gsub("TO", to)
    if body
      result.gsub!(/Hey.*/m, body)
    end
    if subject
      result.sub!(/We .*/, subject)
    end
    result
  end

  def process_email(opts)
    incoming_email = fixture_file("emails/valid_incoming.eml")
    email = fill_email(incoming_email, opts[:from],  opts[:to], opts[:body], opts[:subject])
    Email::Receiver.new(email).process
  end

  describe "with a valid email" do
    let(:reply_key) { "59d8df8370b7e95c5a49fbf86aeb2c93" }
    let(:to) { SiteSetting.reply_by_email_address.gsub("%{reply_key}", reply_key) }

    let(:valid_reply) {
      reply = fixture_file("emails/valid_reply.eml")
      to = SiteSetting.reply_by_email_address.gsub("%{reply_key}", reply_key)
      fill_email(reply, "test@test.com", to)
    }

    let(:receiver) { Email::Receiver.new(valid_reply) }
    let(:post) { create_post }
    let(:user) { post.user }
    let(:email_log) { EmailLog.new(reply_key: reply_key,
                                   post_id: post.id,
                                   topic_id: post.topic_id,
                                   user_id: post.user_id,
                                   post: post,
                                   user: user,
                                   email_type: 'test',
                                   to_address: 'test@test.com'
                                   ) }
    let(:reply_body) {
"I could not disagree more. I am obviously biased but adventure time is the
greatest show ever created. Everyone should watch it.

- Jake out" }

    describe "with an email log" do

      it "extracts data" do
        expect{ receiver.process }.to raise_error(Email::Receiver::EmailLogNotFound)

        email_log.save!
        receiver.process

        expect(receiver.body).to eq(reply_body)
        expect(receiver.email_log).to eq(email_log)
      end

    end

  end

  describe "processes an email to a category" do
    before do
      SiteSetting.email_in = true
    end


    it "correctly can target categories" do
      to = "some@email.com"

      Fabricate(:category, email_in_allow_strangers: false, email_in: to)
      SiteSetting.email_in_min_trust = TrustLevel[4].to_s

      # no email in for user
      expect{
        process_email(from: "cobb@dob.com", to: "invalid@address.com")
      }.to raise_error(Email::Receiver::BadDestinationAddress)

      # valid target invalid user
      expect{
        process_email(from: "cobb@dob.com", to: to)
      }.to raise_error(Email::Receiver::UserNotFoundError)

      # untrusted
      user = Fabricate(:user)
      expect{
        process_email(from: user.email, to: to)
      }.to raise_error(Email::Receiver::UserNotSufficientTrustLevelError)

      # trusted
      user.trust_level = 4
      user.save

      process_email(from: user.email, to: to)
      expect(user.posts.count).to eq(1)

      # email too short
      message = nil
      begin
        process_email(from: user.email, to: to, body: "x", subject: "this is my new topic title")
      rescue Email::Receiver::InvalidPost => e
        message = e.message
      end

      expect(e.message).to include("too short")
    end


    it "blocks user in restricted group from creating topic" do
      to = "some@email.com"

      restricted_user = Fabricate(:user, trust_level: 4)
      restricted_group = Fabricate(:group)
      restricted_group.add(restricted_user)
      restricted_group.save

      category = Fabricate(:category, email_in_allow_strangers: false, email_in: to)
      category.set_permissions(restricted_group => :readonly)
      category.save

      expect{
        process_email(from: restricted_user.email, to: to)
      }.to raise_error(Discourse::InvalidAccess)
    end


  end


  describe "processes an unknown email sender to category" do
    before do
      SiteSetting.email_in = true
    end


    it "rejects anon email" do
      Fabricate(:category, email_in_allow_strangers: false, email_in: "bob@bob.com")
      expect { process_email(from: "test@test.com", to: "bob@bob.com") }.to raise_error(Email::Receiver::UserNotFoundError)
    end

    it "creates a topic for allowed category" do
      Fabricate(:category, email_in_allow_strangers: true, email_in: "bob@bob.com")
      process_email(from: "test@test.com", to: "bob@bob.com")

      # This is the current implementation but it is wrong, it should register an account
      expect(Discourse.system_user.posts.order("id desc").limit(1).pluck(:raw).first).to include("Hey folks")

    end

  end

end

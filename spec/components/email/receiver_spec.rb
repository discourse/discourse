# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'email/receiver'

describe Email::Receiver do

  before do
    SiteSetting.stubs(:reply_by_email_address).returns("reply+%{reply_key}@appmail.adventuretime.ooo")
    SiteSetting.stubs(:email_in).returns(false)
  end

  describe 'invalid emails' do
    it "raises EmptyEmailError if the message is blank" do
      expect { Email::Receiver.new("").process }.to raise_error(Email::Receiver::EmptyEmailError)
    end

    it "raises EmailUnparsableError if the message is not an email" do
      expect { Email::Receiver.new("asdf" * 30).process}.to raise_error(Email::Receiver::EmptyEmailError)
    end
  end

  describe "with multipart" do
    let(:reply_below) { File.read("#{Rails.root}/spec/fixtures/emails/multipart.eml") }
    let(:receiver) { Email::Receiver.new(reply_below) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq(
"So presumably all the quoted garbage and my (proper) signature will get
stripped from my reply?")
    end
  end

  describe "html only" do
    let(:reply_below) { File.read("#{Rails.root}/spec/fixtures/emails/html_only.eml") }
    let(:receiver) { Email::Receiver.new(reply_below) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq("The EC2 instance - I've seen that there tends to be odd and " +
                                  "unrecommended settings on the Bitnami installs that I've checked out.")
    end
  end

  describe "it supports a dutch reply" do
    let(:dutch) { File.read("#{Rails.root}/spec/fixtures/emails/dutch.eml") }
    let(:receiver) { Email::Receiver.new(dutch) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq("Dit is een antwoord in het Nederlands.")
    end
  end

  describe "It supports a non english reply" do
    let(:hebrew) { File.read("#{Rails.root}/spec/fixtures/emails/hebrew.eml") }
    let(:receiver) { Email::Receiver.new(hebrew) }

    it "processes correctly" do
      I18n.expects(:t).with('user_notifications.previous_discussion').returns('כלטוב')
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq("שלום")
    end
  end

  describe "It supports a non UTF-8 reply" do
    let(:big5) { File.read("#{Rails.root}/spec/fixtures/emails/big5.eml") }
    let(:receiver) { Email::Receiver.new(big5) }

    it "processes correctly" do
      I18n.expects(:t).with('user_notifications.previous_discussion').returns('媽！我上電視了！')
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq("媽！我上電視了！")
    end
  end

  describe "via" do
    let(:wrote) { File.read("#{Rails.root}/spec/fixtures/emails/via_line.eml") }
    let(:receiver) { Email::Receiver.new(wrote) }

    it "removes via lines if we know them" do
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq("Hello this email has content!")
    end
  end

  describe "if wrote is on a second line" do
    let(:wrote) { File.read("#{Rails.root}/spec/fixtures/emails/multiline_wrote.eml") }
    let(:receiver) { Email::Receiver.new(wrote) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq("Thanks!")
    end
  end

  describe "remove previous discussion" do
    let(:previous) { File.read("#{Rails.root}/spec/fixtures/emails/previous.eml") }
    let(:receiver) { Email::Receiver.new(previous) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq("This will not include the previous discussion that is present in this email.")
    end
  end

  describe "multiple paragraphs" do
    let(:paragraphs) { File.read("#{Rails.root}/spec/fixtures/emails/paragraphs.eml") }
    let(:receiver) { Email::Receiver.new(paragraphs) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::ProcessingError)
      expect(receiver.body).to eq(
"Is there any reason the *old* candy can't be be kept in silos while the new candy
is imported into *new* silos?

The thing about candy is it stays delicious for a long time -- we can just keep
it there without worrying about it too much, imo.

Thanks for listening.")
    end
  end

  describe "with a valid email" do
    let(:reply_key) { "59d8df8370b7e95c5a49fbf86aeb2c93" }
    let(:valid_reply) { File.read("#{Rails.root}/spec/fixtures/emails/valid_reply.eml") }
    let(:receiver) { Email::Receiver.new(valid_reply) }
    let(:post) { Fabricate.build(:post) }
    let(:user) { Fabricate.build(:user) }
    let(:email_log) { EmailLog.new(reply_key: reply_key, post_id: 1234, topic_id: 4567, user_id: 6677, post: post, user: user ) }
    let(:reply_body) {
"I could not disagree more. I am obviously biased but adventure time is the
greatest show ever created. Everyone should watch it.

- Jake out" }

    describe "email with non-existant email log" do

      before do
        EmailLog.expects(:for).returns(nil)
      end

      it "raises EmailLogNotFoundError" do
        expect{ receiver.process }.to raise_error(Email::Receiver::EmailLogNotFound)
      end

    end

    describe "with an email log" do

      before do
        EmailLog.expects(:for).with(reply_key).returns(email_log)

        creator = mock
        PostCreator.expects(:new).with(instance_of(User),
                                       has_entries(raw: reply_body,
                                                   cooking_options: {traditional_markdown_linebreaks: true}))
                                 .returns(creator)

        creator.expects(:create)
      end

      let!(:result) { receiver.process }

      it "extracts the body" do
        expect(receiver.body).to eq(reply_body)
      end

      it "looks up the email log" do
        expect(receiver.email_log).to eq(email_log)
      end

      it "extracts the key" do
        expect(receiver.reply_key).to eq(reply_key)
      end

    end

    describe "email with attachments" do

      it "can find the message and create a post" do
        user.id = -1
        User.stubs(:find_by_email).returns(user)
        EmailLog.stubs(:for).returns(email_log)
        attachment_email = File.read("#{Rails.root}/spec/fixtures/emails/attachment.eml")
        r = Email::Receiver.new(attachment_email)
        r.expects(:create_post)
        expect { r.process }.to_not raise_error
        expect(r.body).to match(/here is an image attachment\n<img src='\/uploads\/default\/\d+\/\w{16}\.png' width='289' height='126'>\n/)
      end

    end

  end

  describe "processes a valid incoming email" do
    before do
      SiteSetting.stubs(:email_in_address).returns("discourse-in@appmail.adventuretime.ooo")
      SiteSetting.stubs(:email_in_category).returns("42")
      SiteSetting.stubs(:email_in).returns(true)
    end

    let(:incoming_email) { File.read("#{Rails.root}/spec/fixtures/emails/valid_incoming.eml") }
    let(:receiver) { Email::Receiver.new(incoming_email) }
    let(:user) { Fabricate.build(:user, id: 3456) }
    let(:subject) { "We should have a post-by-email-feature." }
    let(:email_body) {
"Hey folks,

I was thinking. Wouldn't it be great if we could post topics via email? Yes it would!

Jakie" }

    describe "email from non user" do

      before do
        User.expects(:find_by_email).returns(nil)
      end

      it "raises user not found error" do
        expect { receiver.process }.to raise_error(Email::Receiver::UserNotFoundError)
      end

    end

    describe "email from untrusted user" do
      before do
        User.expects(:find_by_email).with(
              "jake@adventuretime.ooo").returns(user)
        SiteSetting.stubs(:email_in_min_trust).returns(TrustLevel.levels[:elder].to_s)
      end

      it "raises untrusted user error" do
        expect { receiver.process }.to raise_error(Email::Receiver::UserNotSufficientTrustLevelError)
      end

    end

    describe "with proper user" do

      before do
        SiteSetting.stubs(:email_in_min_trust).returns(TrustLevel.levels[:newuser].to_s)
        User.expects(:find_by_email).with(
              "jake@adventuretime.ooo").returns(user)

        topic_creator = mock()
        TopicCreator.expects(:new).with(instance_of(User),
                                        instance_of(Guardian),
                                        has_entries(title: subject,
                                                    category: 42))
                                 .returns(topic_creator)

        topic_creator.expects(:create).returns(topic_creator)
        topic_creator.expects(:id).twice.returns(12345)


        post_creator = mock
        PostCreator.expects(:new).with(instance_of(User),
                                       has_entries(raw: email_body,
                                                   topic_id: 12345,
                                                   cooking_options: {traditional_markdown_linebreaks: true}))
                                 .returns(post_creator)

        post_creator.expects(:create)

        EmailLog.expects(:create).with(has_entries(
                              email_type: 'topic_via_incoming_email',
                              to_address: "discourse-in@appmail.adventuretime.ooo",
                              user_id: 3456,
                              topic_id: 12345
                              ))
      end

      let!(:result) { receiver.process }

      it "extracts the body" do
        expect(receiver.body).to eq(email_body)
      end

    end

  end


  describe "processes an email to a category" do
    before do
      SiteSetting.stubs(:email_in_address).returns("")
      SiteSetting.stubs(:email_in_category).returns("42")
      SiteSetting.stubs(:email_in).returns(true)
    end

    let(:incoming_email) { File.read("#{Rails.root}/spec/fixtures/emails/valid_incoming.eml") }
    let(:receiver) { Email::Receiver.new(incoming_email) }
    let(:user) { Fabricate.build(:user, id: 3456) }
    let(:category) { Fabricate.build(:category, id: 10) }
    let(:subject) { "We should have a post-by-email-feature." }
    let(:email_body) {
"Hey folks,

I was thinking. Wouldn't it be great if we could post topics via email? Yes it would!

Jakie" }

    describe "category not found" do

      before do
        Category.expects(:find_by_email).returns(nil)
      end

      it "raises EmailLogNotFoundError" do
        expect{ receiver.process }.to raise_error(Email::Receiver::EmailLogNotFound)
      end

    end

    describe "email from non user" do

      before do
        User.expects(:find_by_email).returns(nil)
        Category.expects(:find_by_email).with(
              "discourse-in@appmail.adventuretime.ooo").returns(category)
      end

      it "raises UserNotFoundError" do
        expect{ receiver.process }.to raise_error(Email::Receiver::UserNotFoundError)
      end

    end

    describe "email from untrusted user" do
      before do
        User.expects(:find_by_email).with(
              "jake@adventuretime.ooo").returns(user)
        Category.expects(:find_by_email).with(
              "discourse-in@appmail.adventuretime.ooo").returns(category)
        SiteSetting.stubs(:email_in_min_trust).returns(TrustLevel.levels[:elder].to_s)
      end

      it "raises untrusted user error" do
        expect { receiver.process }.to raise_error(Email::Receiver::UserNotSufficientTrustLevelError)
      end

    end

    describe "with proper user" do

      before do
        SiteSetting.stubs(:email_in_min_trust).returns(
              TrustLevel.levels[:newuser].to_s)
        User.expects(:find_by_email).with(
              "jake@adventuretime.ooo").returns(user)
        Category.expects(:find_by_email).with(
              "discourse-in@appmail.adventuretime.ooo").returns(category)

        topic_creator = mock()
        TopicCreator.expects(:new).with(instance_of(User),
                                        instance_of(Guardian),
                                        has_entries(title: subject,
                                                    category: 10)) # Make sure it is posted to the right category
                                 .returns(topic_creator)

        topic_creator.expects(:create).returns(topic_creator)
        topic_creator.expects(:id).twice.returns(12345)


        post_creator = mock
        PostCreator.expects(:new).with(instance_of(User),
                                       has_entries(raw: email_body,
                                                   topic_id: 12345,
                                                   cooking_options: {traditional_markdown_linebreaks: true}))
                                 .returns(post_creator)

        post_creator.expects(:create)

        EmailLog.expects(:create).with(has_entries(
                              email_type: 'topic_via_incoming_email',
                              to_address: "discourse-in@appmail.adventuretime.ooo",
                              user_id: 3456,
                              topic_id: 12345
                              ))
      end

      let!(:result) { receiver.process }

      it "extracts the body" do
        expect(receiver.body).to eq(email_body)
      end

    end

  end


  describe "processes an unknown email sender to category" do
    before do
      SiteSetting.stubs(:email_in_address).returns("")
      SiteSetting.stubs(:email_in_category).returns("42")
      SiteSetting.stubs(:email_in).returns(true)
    end

    let(:incoming_email) { File.read("#{Rails.root}/spec/fixtures/emails/valid_incoming.eml") }
    let(:receiver) { Email::Receiver.new(incoming_email) }
    let(:non_inbox_email_category) { Fabricate.build(:category, id: 20, email_in_allow_strangers: false) }
    let(:public_inbox_email_category) { Fabricate.build(:category, id: 25, email_in_allow_strangers: true) }
    let(:subject) { "We should have a post-by-email-feature." }
    let(:email_body) { "[quote=\"jake@adventuretime.ooo\"]
Hey folks,

I was thinking. Wouldn't it be great if we could post topics via email? Yes it would!

Jakie
[/quote]" }

    describe "to disabled category" do
      before do
        User.expects(:find_by_email).with(
              "jake@adventuretime.ooo").returns(nil)
        Category.expects(:find_by_email).with(
              "discourse-in@appmail.adventuretime.ooo").returns(non_inbox_email_category)
      end

      it "raises UserNotFoundError" do
        expect{ receiver.process }.to raise_error(Email::Receiver::UserNotFoundError)
      end

    end

    describe "to enabled category" do

      before do
        User.expects(:find_by_email).with(
              "jake@adventuretime.ooo").returns(nil)
        Category.expects(:find_by_email).with(
              "discourse-in@appmail.adventuretime.ooo").returns(public_inbox_email_category)

        topic_creator = mock()
        TopicCreator.expects(:new).with(Discourse.system_user,
                                        instance_of(Guardian),
                                        has_entries(title: subject,
                                                    category: 25)) # Make sure it is posted to the right category
                                 .returns(topic_creator)

        topic_creator.expects(:create).returns(topic_creator)
        topic_creator.expects(:id).twice.returns(135)


        post_creator = mock
        PostCreator.expects(:new).with(Discourse.system_user,
                                       has_entries(raw: email_body,
                                                   topic_id: 135,
                                                   cooking_options: {traditional_markdown_linebreaks: true}))
                                 .returns(post_creator)

        post_creator.expects(:create)

        EmailLog.expects(:create).with(has_entries(
                              email_type: 'topic_via_incoming_email',
                              to_address: "discourse-in@appmail.adventuretime.ooo",
                              user_id: Discourse.system_user.id,
                              topic_id: 135
                              ))
      end

      let!(:result) { receiver.process }

      it "extracts the body" do
        expect(receiver.body).to eq(email_body)
      end

    end

  end

end

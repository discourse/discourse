require 'spec_helper'
require 'email/receiver'

describe Email::Receiver do

  before do
    SiteSetting.stubs(:reply_by_email_address).returns("reply+%{reply_key}@appmail.adventuretime.ooo")
  end

  describe 'invalid emails' do
    it "returns unprocessable if the message is blank" do
      expect(Email::Receiver.new("").process).to eq(Email::Receiver.results[:unprocessable])
    end

    it "returns unprocessable if the message is not an email" do
      expect(Email::Receiver.new("asdf" * 30).process).to eq(Email::Receiver.results[:unprocessable])
    end
  end

  describe "with multipart" do
    let(:reply_below) { File.read("#{Rails.root}/spec/fixtures/emails/multipart.eml") }
    let(:receiver) { Email::Receiver.new(reply_below) }

    it "processes correctly" do
      receiver.process
      expect(receiver.body).to eq(
"So presumably all the quoted garbage and my (proper) signature will get
stripped from my reply?")
    end
  end

  describe "html only" do
    let(:reply_below) { File.read("#{Rails.root}/spec/fixtures/emails/html_only.eml") }
    let(:receiver) { Email::Receiver.new(reply_below) }

    it "processes correctly" do
      receiver.process
      expect(receiver.body).to eq("The EC2 instance - I've seen that there tends to be odd and " +
                                  "unrecommended settings on the Bitnami installs that I've checked out.")
    end
  end

  describe "it supports a dutch reply" do
    let(:dutch) { File.read("#{Rails.root}/spec/fixtures/emails/dutch.eml") }
    let(:receiver) { Email::Receiver.new(dutch) }

    it "processes correctly" do
      receiver.process
      expect(receiver.body).to eq("Dit is een antwoord in het Nederlands.")
    end
  end

  describe "It supports a non english reply" do
    let(:hebrew) { File.read("#{Rails.root}/spec/fixtures/emails/hebrew.eml") }
    let(:receiver) { Email::Receiver.new(hebrew) }

    it "processes correctly" do
      I18n.expects(:t).with('user_notifications.previous_discussion').returns('כלטוב')
      receiver.process
      expect(receiver.body).to eq("שלום")
    end
  end

  describe "via" do
    let(:wrote) { File.read("#{Rails.root}/spec/fixtures/emails/via_line.eml") }
    let(:receiver) { Email::Receiver.new(wrote) }

    it "removes via lines if we know them" do
      receiver.process
      expect(receiver.body).to eq("Hello this email has content!")
    end
  end

  describe "if wrote is on a second line" do
    let(:wrote) { File.read("#{Rails.root}/spec/fixtures/emails/multiline_wrote.eml") }
    let(:receiver) { Email::Receiver.new(wrote) }

    it "processes correctly" do
      receiver.process
      expect(receiver.body).to eq("Thanks!")
    end
  end

  describe "remove previous discussion" do
    let(:previous) { File.read("#{Rails.root}/spec/fixtures/emails/previous.eml") }
    let(:receiver) { Email::Receiver.new(previous) }

    it "processes correctly" do
      receiver.process
      expect(receiver.body).to eq("This will not include the previous discussion that is present in this email.")
    end
  end

  describe "multiple paragraphs" do
    let(:paragraphs) { File.read("#{Rails.root}/spec/fixtures/emails/paragraphs.eml") }
    let(:receiver) { Email::Receiver.new(paragraphs) }

    it "processes correctly" do
      receiver.process
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

      let!(:result) { receiver.process }

      it "returns missing" do
        expect(result).to eq(Email::Receiver.results[:missing])
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

      it "returns a processed result" do
        expect(result).to eq(Email::Receiver.results[:processed])
      end

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

  end


end

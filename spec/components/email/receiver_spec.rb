# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'email/receiver'

describe Email::Receiver do

  before do
    SiteSetting.reply_by_email_address = "reply+%{reply_key}@appmail.adventuretime.ooo"
    SiteSetting.email_in = false
  end

  describe 'invalid emails' do
    it "raises EmptyEmailError if the message is blank" do
      expect { Email::Receiver.new("").process }.to raise_error(Email::Receiver::EmptyEmailError)
    end

    it "raises EmptyEmailError if the message is not an email" do
      expect { Email::Receiver.new("asdf" * 30).process}.to raise_error(Email::Receiver::EmptyEmailError)
    end

    it "raises EmailUnparsableError if there is no reply content" do
      expect { Email::Receiver.new(fixture_file("emails/no_content_reply.eml")).process}.to raise_error(Email::Receiver::EmailUnparsableError)
    end
  end

  describe "with multipart" do
    let(:reply_below) { fixture_file("emails/multipart.eml") }
    let(:receiver) { Email::Receiver.new(reply_below) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq(
"So presumably all the quoted garbage and my (proper) signature will get
stripped from my reply?")
    end
  end

  describe "html only" do
    let(:reply_below) { fixture_file("emails/html_only.eml") }
    let(:receiver) { Email::Receiver.new(reply_below) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq("The EC2 instance - I've seen that there tends to be odd and " +
                                  "unrecommended settings on the Bitnami installs that I've checked out.")
    end
  end

  describe "it supports a dutch reply" do
    let(:dutch) { fixture_file("emails/dutch.eml") }
    let(:receiver) { Email::Receiver.new(dutch) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq("Dit is een antwoord in het Nederlands.")
    end
  end

  describe "It supports a non english reply" do
    let(:hebrew) { fixture_file("emails/hebrew.eml") }
    let(:receiver) { Email::Receiver.new(hebrew) }

    it "processes correctly" do
      I18n.expects(:t).with('user_notifications.previous_discussion').returns('כלטוב')
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq("שלום")
    end
  end

  describe "It supports a non UTF-8 reply" do
    let(:big5) { fixture_file("emails/big5.eml") }
    let(:receiver) { Email::Receiver.new(big5) }

    it "processes correctly" do
      I18n.expects(:t).with('user_notifications.previous_discussion').returns('媽！我上電視了！')
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq("媽！我上電視了！")
    end
  end

  describe "via" do
    let(:wrote) { fixture_file("emails/via_line.eml") }
    let(:receiver) { Email::Receiver.new(wrote) }

    it "removes via lines if we know them" do
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq("Hello this email has content!")
    end
  end

  describe "if wrote is on a second line" do
    let(:wrote) { fixture_file("emails/multiline_wrote.eml") }
    let(:receiver) { Email::Receiver.new(wrote) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq("Thanks!")
    end
  end

  describe "remove previous discussion" do
    let(:previous) { fixture_file("emails/previous.eml") }
    let(:receiver) { Email::Receiver.new(previous) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq("This will not include the previous discussion that is present in this email.")
    end
  end

  describe "multiple paragraphs" do
    let(:paragraphs) { fixture_file("emails/paragraphs.eml") }
    let(:receiver) { Email::Receiver.new(paragraphs) }

    it "processes correctly" do
      expect { receiver.process}.to raise_error(Email::Receiver::EmailLogNotFound)
      expect(receiver.body).to eq(
"Is there any reason the *old* candy can't be be kept in silos while the new candy
is imported into *new* silos?

The thing about candy is it stays delicious for a long time -- we can just keep
it there without worrying about it too much, imo.

Thanks for listening.")
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

        attachment_email = fixture_file("emails/attachment.eml")
        attachment_email = fill_email(attachment_email, "test@test.com", to)
        r = Email::Receiver.new(attachment_email)
        expect { r.process }.to_not raise_error
        expect(r.body).to match(/here is an image attachment\n<img src='\/uploads\/default\/\d+\/\w{16}\.png' width='289' height='126'>\n/)
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
      SiteSetting.email_in_min_trust = TrustLevel.levels[:elder].to_s

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
      user.posts.count.should == 1

      # email too short
      message = nil
      begin
        process_email(from: user.email, to: to, body: "x", subject: "this is my new topic title")
      rescue Email::Receiver::InvalidPost => e
        message = e.message
      end

      e.message.should include("too short")
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
      Discourse.system_user.posts.order("id desc").limit(1).pluck(:raw).first.should include("Hey folks")

    end

  end

end

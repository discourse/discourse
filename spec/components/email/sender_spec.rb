require 'rails_helper'
require 'email/sender'

describe Email::Sender do

  it "doesn't deliver mail when mails are disabled" do
    SiteSetting.disable_emails = true
    Mail::Message.any_instance.expects(:deliver_now).never
    message = Mail::Message.new(to: "hello@world.com" , body: "hello")
    expect(Email::Sender.new(message, :hello).send).to eq(nil)
  end

  it "delivers mail when mails are disabled but the email_type is admin_login" do
    SiteSetting.disable_emails = true
    Mail::Message.any_instance.expects(:deliver_now).once
    message = Mail::Message.new(to: "hello@world.com" , body: "hello")
    Email::Sender.new(message, :admin_login).send
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
      message = Mail::Message.new to: 'eviltrout@test.domain',
                                  body: '**hello**'
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

      When { email_sender.send }
      Then {
        expect(message.header[:return_path].to_s).to eq("")
      }
    end

    context "adds return_path with plus addressing" do
      before { SiteSetting.reply_by_email_address = 'replies+%{reply_key}@test.com' }

      When { email_sender.send }
      Then {
        expect(message.header[:return_path].to_s).to eq("replies+verp-#{EmailLog.last.bounce_key}@test.com")
      }
    end

    context "adds a List-ID header to identify the forum" do
      before do
        category =  Fabricate(:category, name: 'Name With Space')
        topic = Fabricate(:topic, category_id: category.id)
        message.header['X-Discourse-Topic-Id'] = topic.id
      end

      When { email_sender.send }
      Then { expect(message.header['List-ID']).to be_present }
      Then { expect(message.header['List-ID'].to_s).to match('name-with-space') }
    end

    context "adds a Message-ID header even when topic id is not present" do
      When { email_sender.send }
      Then { expect(message.header['Message-ID']).to be_present }
    end

    context "adds Precedence header" do
      before do
        message.header['X-Discourse-Topic-Id'] = 5577
      end

      When { email_sender.send }
      Then { expect(message.header['Precedence']).to be_present }
    end

    context "removes custom Discourse headers from topic notification mails" do
      before do
        message.header['X-Discourse-Topic-Id'] = 5577
      end

      When { email_sender.send }
      Then { expect(message.header['X-Discourse-Topic-Id']).not_to be_present }
      Then { expect(message.header['X-Discourse-Post-Id']).not_to be_present }
      Then { expect(message.header['X-Discourse-Reply-Key']).not_to be_present }
    end

    context "removes custom Discourse headers from digest/registration/other mails" do
      When { email_sender.send }
      Then { expect(message.header['X-Discourse-Topic-Id']).not_to be_present }
      Then { expect(message.header['X-Discourse-Post-Id']).not_to be_present }
      Then { expect(message.header['X-Discourse-Reply-Key']).not_to be_present }
    end

    context 'email logs' do
      let(:email_log) { EmailLog.last }

      When { email_sender.send }
      Then { expect(email_log).to be_present }
      Then { expect(email_log.email_type).to eq('valid_type') }
      Then { expect(email_log.to_address).to eq('eviltrout@test.domain') }
      Then { expect(email_log.reply_key).to be_blank }
      Then { expect(email_log.user_id).to be_blank }
    end

    context "email log with a post id and topic id" do
      before do
        message.header['X-Discourse-Post-Id'] = 3344
        message.header['X-Discourse-Topic-Id'] = 5577
      end

      let(:email_log) { EmailLog.last }
      When { email_sender.send }
      Then { expect(email_log.post_id).to eq(3344) }
      Then { expect(email_log.topic_id).to eq(5577) }
      Then { expect(message.header['In-Reply-To']).to be_present }
      Then { expect(message.header['References']).to be_present }

    end

    context "email log with a reply key" do
      before do
        message.header['X-Discourse-Reply-Key'] = reply_key
      end

      let(:email_log) { EmailLog.last }
      When { email_sender.send }
      Then { expect(email_log.reply_key).to eq(reply_key) }
    end


    context 'email parts' do
      When { email_sender.send }
      Then { expect(message).to be_multipart }
      Then { expect(message.text_part.content_type).to eq('text/plain; charset=UTF-8') }
      Then { expect(message.html_part.content_type).to eq('text/html; charset=UTF-8') }
      Then { expect(message.html_part.body.to_s).to match("<p><strong>hello</strong></p>") }
    end
  end

  context 'with a user' do
    let(:message) do
      message = Mail::Message.new to: 'eviltrout@test.domain', body: 'test body'
      message.stubs(:deliver_now)
      message
    end

    let(:user) { Fabricate(:user) }
    let(:email_sender) { Email::Sender.new(message, :valid_type, user) }

    before do
      email_sender.send
      @email_log = EmailLog.last
    end

    it 'should have the current user_id' do
      expect(@email_log.user_id).to eq(user.id)
    end


  end

end

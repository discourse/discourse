# frozen_string_literal: true
require 'rails_helper'
require 'email/receiver'

describe GroupSmtpMailer do
  let(:group) do
    Fabricate(:group,
              name: 'Testers',
              title: 'Tester',
              full_name: 'Testers Group',
              smtp_server: 'smtp.gmail.com',
              smtp_port: 587,
              smtp_ssl: true,
              smtp_enabled: true,
              imap_server: 'imap.gmail.com',
              imap_port: 993,
              imap_ssl: true,
              imap_enabled: true,
              email_username: 'bugs@gmail.com',
              email_password: 'super$secret$password'
             )
  end

  let(:user) do
    user = Fabricate(:user)
    group.add_owner(user)
    user
  end

  let(:email) do
    <<~EOF
    Delivered-To: bugs@gmail.com
    MIME-Version: 1.0
    From: John Doe <john@doe.com>
    Date: Tue, 01 Jan 2019 12:00:00 +0200
    Message-ID: <a52f67a3d3560f2a35276cda8519b10b595623bcb66912bb92df6651ad5f75be@mail.gmail.com>
    Subject: Hello from John
    To: "bugs@gmail.com" <bugs@gmail.com>
    Content-Type: text/plain; charset="UTF-8"

    Hello,

    How are you doing?
    EOF
  end

  let(:receiver) do
    receiver = Email::Receiver.new(
      email,
      destinations: [group],
      uid_validity: 1,
      uid: 10000
    )
    receiver.process!
    receiver
  end

  let(:raw) { 'hello, how are you doing?' }

  before do
    SiteSetting.enable_smtp = true
    SiteSetting.enable_imap = true
    Jobs.run_immediately!
    SiteSetting.manual_polling_enabled = true
    SiteSetting.reply_by_email_address = "test+%{reply_key}@test.com"
    SiteSetting.reply_by_email_enabled = true
  end

  it 'sends an email as reply' do
    post = PostCreator.create(user,
                              topic_id: receiver.incoming_email.topic.id,
                              raw: raw
                             )

    expect(ActionMailer::Base.deliveries.size).to eq(1)

    sent_mail = ActionMailer::Base.deliveries[0]
    expect(sent_mail.to).to contain_exactly('john@doe.com')
    expect(sent_mail.reply_to).to eq(nil)
    expect(sent_mail.subject).to eq('Re: Hello from John')
    expect(sent_mail.to_s).to include(raw)
  end

  it "uses the OP incoming email subject for the subject over topic title" do
    receiver.incoming_email.topic.update(title: "blah")
    post = PostCreator.create(user,
                              topic_id: receiver.incoming_email.topic.id,
                              raw: raw
                             )
    sent_mail = ActionMailer::Base.deliveries[0]
    expect(sent_mail.subject).to eq('Re: Hello from John')
  end

  context "when the site has a reply by email address configured" do
    before do
      SiteSetting.manual_polling_enabled = true
      SiteSetting.reply_by_email_address = "test+%{reply_key}@test.com"
      SiteSetting.reply_by_email_enabled = true
    end

    it 'uses the correct IMAP/SMTP reply to address and does not create a post reply key' do
      post = PostCreator.create(user,
                                topic_id: receiver.incoming_email.topic.id,
                                raw: raw
                               )

      expect(ActionMailer::Base.deliveries.size).to eq(1)

      expect(PostReplyKey.find_by(user_id: user.id, post_id: post.id)).to eq(nil)

      sent_mail = ActionMailer::Base.deliveries[0]
      expect(sent_mail.reply_to).to eq(nil)
      expect(sent_mail.from).to contain_exactly('bugs@gmail.com')
    end

    context "when IMAP is disabled for the group" do
      before do
        group.update(imap_enabled: false)
      end

      it "does send the email" do
        post = PostCreator.create(user,
                                  topic_id: receiver.incoming_email.topic.id,
                                  raw: raw
                                 )

        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end
    end

    context "when SMTP is disabled for the group" do
      before do
        group.update(smtp_enabled: false)
      end

      it "does not send the email" do
        post = PostCreator.create(user,
                                  topic_id: receiver.incoming_email.topic.id,
                                  raw: raw
                                 )

        expect(ActionMailer::Base.deliveries.size).to eq(0)
      end
    end
  end
end

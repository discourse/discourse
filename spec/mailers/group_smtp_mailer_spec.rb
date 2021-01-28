# frozen_string_literal: true
require 'rails_helper'
require 'email/receiver'

describe GroupSmtpMailer do
  let(:group) {
    Fabricate(:group,
              name: 'Testers',
              title: 'Tester',
              full_name: 'Testers Group',
              smtp_server: 'smtp.gmail.com',
              smtp_port: 587,
              smtp_ssl: true,
              imap_server: 'imap.gmail.com',
              imap_port: 993,
              imap_ssl: true,
              email_username: 'bugs@gmail.com',
              email_password: 'super$secret$password'
             )
  }

  let(:user) {
    user = Fabricate(:user)
    group.add_owner(user)
    user
  }

  let(:email) {
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
  }

  let(:receiver) {
    receiver = Email::Receiver.new(email,
                                   destinations: [group],
                                   uid_validity: 1,
                                   uid: 10000
                                  )
  receiver.process!
  receiver
  }

  let(:raw) { 'hello, how are you doing?' }

  before do
    SiteSetting.enable_smtp = true
    SiteSetting.enable_imap = true
    Jobs.run_immediately!
  end

  it 'sends an email as reply' do
    post = PostCreator.create(user,
                              topic_id: receiver.incoming_email.topic.id,
                              raw: raw
                             )

    expect(ActionMailer::Base.deliveries.size).to eq(1)

    sent_mail = ActionMailer::Base.deliveries[0]
    expect(sent_mail.to).to contain_exactly('john@doe.com')
    expect(sent_mail.reply_to).to contain_exactly('bugs@gmail.com')
    expect(sent_mail.subject).to eq('Re: Hello from John')
    expect(sent_mail.to_s).to include(raw)
  end

  context "when the site has a reply by email address configured" do
    before do
      SiteSetting.manual_polling_enabled = true
      SiteSetting.reply_by_email_address = "test+%{reply_key}@test.com"
      SiteSetting.reply_by_email_enabled = true
    end

    it 'uses the correct IMAP/SMTP reply to address' do
      post = PostCreator.create(user,
                                topic_id: receiver.incoming_email.topic.id,
                                raw: raw
                               )

      expect(ActionMailer::Base.deliveries.size).to eq(1)

      sent_mail = ActionMailer::Base.deliveries[0]
      expect(sent_mail.reply_to).to contain_exactly('bugs@gmail.com')
    end

    context "when IMAP is disabled for the group" do
      before do
        group.update(
          imap_server: nil
        )
      end

      it "uses the reply key based reply to address" do
        post = PostCreator.create(user,
                                  topic_id: receiver.incoming_email.topic.id,
                                  raw: raw
                                 )

        expect(ActionMailer::Base.deliveries.size).to eq(1)

        sent_mail = ActionMailer::Base.deliveries[0]
        post_reply_key = PostReplyKey.last
        expect(sent_mail.reply_to).to contain_exactly("test+#{post_reply_key.reply_key}@test.com")
      end
    end
  end
end

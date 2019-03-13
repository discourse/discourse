class MockedImapProvider < Imap::Providers::Gmail
  def connect!
  end

  def disconnect!
  end

  def select_mailbox(mailbox)
  end
end

def EmailFabricator(options)
  <<~TXT
    Delivered-To: #{options[:to] || "joffrey@discourse.org"}
    MIME-Version: 1.0
    From: #{options[:from] || "John <john@free.fr>"}
    Date: Sat, 31 Mar 2018 17:50:19 -0700
    Subject: #{options[:subject] || "This is the email post"}
    To: #{options[:to] || "joffrey@discourse.org"}
    Content-Type: text/plain; charset="UTF-8"

    #{options[:body] || "This is the email *body*. :smile:"}
  TXT
end

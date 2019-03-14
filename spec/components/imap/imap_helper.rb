class MockedImapProvider < Imap::Providers::Gmail
  def connect!
  end

  def disconnect!
  end

  def select_mailbox(mailbox)
  end

  def labels
    ["INBOX"]
  end
end

def EmailFabricator(options)
  email = ""

  if options[:in_reply_to]
    email += <<~TXT
      In-Reply-To: #{options[:in_reply_to]}
      References: #{options[:in_reply_to]}
    TXT
  end

  if options[:message_id]
    email += <<~TXT
      Message-ID: #{options[:message_id]}
    TXT
  end

  email += <<~TXT
    MIME-Version: 1.0
    To: #{options[:to] || "Joffrey <joffrey@discourse.org>"}
    From: #{options[:from] || "Dan <dan@discourse.org>"}
    Date: Sat, 31 Mar 2018 17:50:19 -0700
    Subject: #{options[:subject] || "This is a test email subhect"}
    To: #{options[:to] || "Joffrey <joffrey@discourse.org>"}
    Content-Type: #{options[:content_type] || 'text/plain; charset="UTF-8"'}

    #{options[:body] || "This is an email *body*. :smile:"}
  TXT

  email
end

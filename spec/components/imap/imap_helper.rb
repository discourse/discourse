class MockedImapProvider < Imap::Providers::Gmail
  def connect!; end
  def disconnect!; end
  def open_mailbox(mailbox, write = false); end

  def labels
    ["INBOX"]
  end
end

def EmailFabricator(options)
  email = ""

  if options[:in_reply_to]
    email += "In-Reply-To: #{options[:in_reply_to]}\n"
    email += "References: #{options[:in_reply_to]}\n"
  end

  if options[:message_id]
    email += "Message-ID: #{options[:message_id]}\n"
  end

  if options[:cc]
    email += "Cc: #{options[:cc]}\n"
  end

  email += <<~TXT
    MIME-Version: 1.0
    To: #{options[:to] || "Joffrey <joffrey@discourse.org>"}
    From: #{options[:from] || "Dan <dan@discourse.org>"}
    Date: Sat, 31 Mar 2018 17:50:19 -0700
    Subject: #{options[:subject] || "This is a test email subhect"}
    Content-Type: #{options[:content_type] || 'text/plain; charset="UTF-8"'}

    #{options[:body] || "This is an email *body*. :smile:"}
  TXT
end

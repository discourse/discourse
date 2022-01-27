# frozen_string_literal: true

class MockedImapProvider < Imap::Providers::Gmail
  def connect!; end
  def disconnect!; end
  def open_mailbox(mailbox_name, write: false); end

  def labels
    ['INBOX']
  end
end

def EmailFabricator(options)
  email = +''
  email += "Date: Sat, 31 Mar 2018 17:50:19 -0700\n"
  email += "From: #{options[:from] || "Dan <dan@discourse.org>"}\n"
  email += "To: #{options[:to] || "Joffrey <joffrey@discourse.org>"}\n"
  email += "Cc: #{options[:cc]}\n" if options[:cc]
  email += "In-Reply-To: #{options[:in_reply_to]}\n" if options[:in_reply_to]
  email += "References: #{options[:in_reply_to]}\n" if options[:in_reply_to]
  email += "Message-ID: <#{options[:message_id]}>\n" if options[:message_id]
  email += "Subject: #{options[:subject] || "This is a test email subject"}\n"
  email += "Mime-Version: 1.0\n"
  email += "Content-Type: #{options[:content_type] || "text/plain;\n charset=UTF-8"}\n"
  email += "Content-Transfer-Encoding: 7bit\n"
  email += "\n#{options[:body] || "This is an email *body*. :smile:"}"
  email
end

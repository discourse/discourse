# frozen_string_literal: true

desc "removes attachments and truncates long raw message"
task "incoming_emails:truncate_long" => :environment do
  IncomingEmail.find_each do |incoming_email|
    truncated_raw = Email::Cleaner.new(incoming_email.raw, rejected: incoming_email.rejection_message.present?).execute

    # raw email is using \n as line separator, mail gem is using \r\n
    # we need to determine if anything change to avoid updating all records
    changed = truncated_raw != Mail.new(incoming_email.raw).to_s

    incoming_email.update(raw: truncated_raw) if changed
  end
end

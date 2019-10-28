# frozen_string_literal: true

desc "removes attachments and truncates long raw message"
task "incoming_emails:truncate_long" => :environment do
  IncomingEmail.find_each do |incoming_email|
    # raw email is using \n as line separator, mail gem is using \r\n
    # therefor size is compared to not update every record
    truncated_raw = Email::Cleaner.new(incoming_email.raw, rejected: incoming_email.rejection_message.present?).execute
    changed = truncated_raw.gsub(/[\r\n]/, "").size != incoming_email.raw.gsub(/[\r\n]/, "").size
    incoming_email.update(raw: truncated_raw) if changed
  end
end

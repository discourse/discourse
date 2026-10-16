# frozen_string_literal: true

module Jobs
  class DsaNoticeReceipt < ::Jobs::Base
    def execute(args)
      DistributedMutex.synchronize("dsa-notice-receipt-#{args.fetch(:topic_id)}") do
        topic = Topic.find_by(id: args[:topic_id])
        notice = topic&.custom_fields&.fetch("dsa_notice", nil)
        if notice.blank? || notice["email"].blank? ||
             topic.custom_fields["dsa_notice_receipt_sent"] == "t"
          return
        end

        message = DsaNoticeMailer.receipt(notice)
        sent = Email::Sender.new(message, :dsa_notice_receipt).send
        if sent.is_a?(EmailLog) && sent.persisted?
          topic.upsert_custom_fields("dsa_notice_receipt_sent" => "t")
        end
      end
    end
  end
end

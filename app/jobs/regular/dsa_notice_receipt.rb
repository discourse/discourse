# frozen_string_literal: true

module Jobs
  class DsaNoticeReceipt < ::Jobs::Base
    class DeliverySuppressed < StandardError
    end

    def execute(args)
      DistributedMutex.synchronize("dsa-notice-receipt-#{args.fetch(:post_id)}") do
        notice = Dsa::Notice.from_post(Post.find_by(id: args[:post_id]))
        return if !notice || notice.email.blank? || notice.receipt_sent?

        sent = Email::Sender.new(DsaNoticeMailer.receipt(notice), :dsa_notice_receipt).send
        if sent.is_a?(EmailLog) && sent.persisted?
          notice.mark_receipt_sent!
        elsif sent.nil?
          raise DeliverySuppressed, "Receipt delivery is disabled for notice #{notice.reference}"
        end
      end
    end
  end
end

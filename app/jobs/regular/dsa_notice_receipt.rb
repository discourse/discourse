# frozen_string_literal: true

module Jobs
  class DsaNoticeReceipt < ::Jobs::Base
    def execute(args)
      DistributedMutex.synchronize("dsa-notice-receipt-#{args.fetch(:post_id)}") do
        notice = Dsa::Notice.from_post(Post.find_by(id: args[:post_id]))
        return if !notice || notice.email.blank? || notice.receipt_sent?

        sent = Email::Sender.new(DsaNoticeMailer.receipt(notice), :dsa_notice_receipt).send
        if sent.is_a?(EmailLog) && sent.persisted?
          notice.mark_receipt_sent!
        elsif sent.nil?
          Jobs.enqueue_in(1.hour, :dsa_notice_receipt, post_id: notice.post.id)
        end
      end
    end
  end
end

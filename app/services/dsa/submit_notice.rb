# frozen_string_literal: true

module Dsa
  class SubmitNotice
    include Service::Base

    policy :enabled
    options { attribute :ip_address, :string }

    params do
      attribute :notice do
        attribute :submission_id, :string
        attribute :content_url, :string
        attribute :explanation, :string
        attribute :anonymous, :boolean, default: false
        attribute :name, :string
        attribute :email, :string
        attribute :declaration, :boolean

        before_validation do
          @valid_shape =
            raw_attributes.all? do |field, value|
              if %w[anonymous declaration].include?(field)
                [nil, true, false, "true", "false", "1", "0", 1, 0].include?(value)
              else
                value.nil? || value.is_a?(String)
              end
            end
          self.submission_id = submission_id.to_s.downcase
          self.content_url = content_url.to_s.strip
          self.explanation = explanation.to_s.strip
          self.name = anonymous ? nil : name.to_s.strip
          self.email = anonymous ? nil : email.to_s.strip.downcase
        end

        validates :submission_id,
                  format: {
                    with: /\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/,
                  }
        validates :content_url, presence: true, length: { maximum: 2048 }
        validates :explanation, length: { minimum: 50, maximum: 20_000 }
        validates :declaration, inclusion: { in: [true] }
        validates :anonymous, inclusion: { in: [true, false] }
        validates :name, presence: true, length: { maximum: 200 }, unless: :anonymous
        validates :email, presence: true, length: { maximum: 254 }, unless: :anonymous
        validate :valid_shape
        validate :valid_content_url
        validate :valid_email

        private

        def valid_shape
          errors.add(:base, I18n.t("dsa_notice.invalid_parameters")) unless @valid_shape
        end

        def valid_content_url
          uri = URI.parse(content_url)
          if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? &&
               !content_url.match?(/[\s<>]/)
            return
          end
          errors.add(:content_url, I18n.t("dsa_notice.invalid_url"))
        rescue URI::InvalidURIError
          errors.add(:content_url, I18n.t("dsa_notice.invalid_url"))
        end

        def valid_email
          return if anonymous || (Email.is_valid?(email) && !email.match?(/[\r\n]/))
          errors.add(:email, I18n.t("dsa_notice.invalid_email"))
        end
      end

      validates :notice, presence: true
      delegate :submission_id, to: :notice
    end

    step :rate_limit_lookup
    lock :submission_id do
      model :notice, :find_notice, optional: true
      policy :matches_submission
      only_if(:new_notice) do
        step :rate_limit_notice
        transaction { model :notice, :create_notice }
      end

      try do
        only_if(:group_notifications_pending) { step :enqueue_group_notifications }
        only_if(:receipt_pending) { step :enqueue_receipt }
      end
    end

    private

    def enabled
      SiteSetting.dsa_reporting_enabled
    end

    def rate_limit_lookup(options:)
      RateLimiter.new(nil, "dsa-notice-lookups", 1000, 1.hour).performed!
      if options.ip_address.present?
        RateLimiter.new(nil, "dsa-notice-lookups-ip-#{options.ip_address}", 20, 1.hour).performed!
      end
    end

    def find_notice(params:)
      Dsa::Notice.find(submission_id: params.notice.submission_id)
    end

    def matches_submission(params:, notice:)
      notice.nil? || notice.matches?(params.notice.to_hash)
    end

    def new_notice(notice:)
      notice.nil?
    end

    def rate_limit_notice(params:, options:)
      if options.ip_address.present?
        RateLimiter.new(nil, "dsa-notice-ip-#{options.ip_address}", 5, 1.hour).performed!
      end
      RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed!
      unless params.notice.anonymous
        email_key = Digest::SHA256.hexdigest(params.notice.email)
        RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day).performed!
      end
    end

    def create_notice(params:)
      group = Group.find_by(id: SiteSetting.dsa_notice_group)
      group = Group[:admins] if !group || !group.users.exists?
      Dsa::Notice.create!(attributes: params.notice.to_hash, group:)
    end

    def group_notifications_pending(notice:)
      !notice.group_notified?
    end

    def enqueue_group_notifications(notice:)
      PostJobsEnqueuer.new(notice.post, notice.post.topic, true).enqueue_jobs
      notice.mark_group_notified!
    end

    def receipt_pending(notice:)
      notice.email.present? && !notice.receipt_sent?
    end

    def enqueue_receipt(notice:)
      Jobs.enqueue(:dsa_notice_receipt, post_id: notice.post.id)
    end
  end
end

# frozen_string_literal: true

module Dsa
  class SubmitNotice
    include Service::Base

    options { attribute :ip_address, :string }

    params do
      attribute :notice do
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
          self.content_url = content_url.to_s.strip
          self.explanation = explanation.to_s.strip
          self.name = anonymous ? nil : name.to_s.strip
          self.email = anonymous ? nil : email.to_s.strip.downcase
        end

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
    end

    step :rate_limit_notice
    model :notice, :create_notice
    step :enqueue_group_notifications
    only_if(:receipt_pending) { step :enqueue_receipt }

    private

    def rate_limit_notice(params:, options:)
      if options.ip_address.present?
        RateLimiter.new(nil, "dsa-notice-ip-#{options.ip_address}", 5, 1.hour).performed!
      end
      unless params.notice.anonymous
        email_key = Digest::SHA256.hexdigest(params.notice.email)
        email_limiter = RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day)
        email_limiter.performed!
      end
      begin
        RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed!
      rescue RateLimiter::LimitExceeded
        email_limiter&.rollback!
        raise
      end
    end

    def create_notice(params:)
      group = Group.find_by(id: SiteSetting.dsa_notice_group)
      group = Group[:admins] if !group || !group.users.exists?
      Dsa::Notice.create_with_post!(attributes: params.notice.to_hash, group:)
    end

    def enqueue_group_notifications(notice:)
      PostJobsEnqueuer.new(notice.post, notice.post.topic, true).enqueue_jobs
      notice.mark_group_notified!
    end

    def receipt_pending(notice:)
      notice.email.present?
    end

    def enqueue_receipt(notice:)
      Jobs.enqueue(:dsa_notice_receipt, notice_id: notice.id)
    end
  end
end

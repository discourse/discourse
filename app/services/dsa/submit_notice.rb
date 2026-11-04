# frozen_string_literal: true

module Dsa
  class SubmitNotice
    include Service::Base

    params do
      attribute :notice do
        attribute :content_url, :string
        attribute :explanation, :string
        attribute :name, :string
        attribute :email, :string
        attribute :declaration, :boolean

        before_validation do
          @valid_shape =
            raw_attributes.all? do |field, value|
              if field == "declaration"
                [nil, true, false, "true", "false", "1", "0", 1, 0].include?(value)
              else
                value.nil? || value.is_a?(String)
              end
            end
          self.content_url = content_url.to_s.strip
          self.explanation = explanation.to_s.strip
          self.name = name.to_s.strip
          self.email = email.to_s.strip.downcase
        end

        validates :content_url, presence: true, length: { maximum: 2048 }
        validates :explanation, length: { minimum: 50, maximum: 20_000 }
        validates :declaration, inclusion: { in: [true] }
        validates :name, presence: true, length: { maximum: 200 }
        validates :email, presence: true, length: { maximum: 254 }
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
          return if Email.is_valid?(email) && !email.match?(/[\r\n]/)
          errors.add(:email, I18n.t("dsa_notice.invalid_email"))
        end
      end

      attribute :token, :string

      validates :notice, presence: true
      validates :token, length: { is: 64 }, allow_blank: true
    end

    model :verification
    model :notice, :create_notice
    step :enqueue_group_notifications
    step :enqueue_receipt

    private

    def fetch_verification(guardian:, params:)
      if params.notice.email == Dsa::Notice.verified_account_email(guardian.user)
        return { email: params.notice.email }
      end

      Dsa::NoticeVerification.consume(token: params.token, email: params.notice.email)
    end

    def create_notice(params:)
      group = Group.find_by(id: SiteSetting.dsa_notice_group)
      group = Group[:admins] if !group || !group.users.exists?
      Dsa::Notice.create_with_post!(attributes: params.notice.to_hash.except(:declaration), group:)
    end

    def enqueue_group_notifications(notice:)
      PostJobsEnqueuer.new(notice.post, notice.post.topic, true).enqueue_jobs
    end

    def enqueue_receipt(notice:)
      Jobs.enqueue(:dsa_notice_receipt, notice_id: notice.id)
    end
  end
end

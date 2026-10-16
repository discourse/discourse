# frozen_string_literal: true

module Dsa
  class SubmitNotice
    include Service::Base

    params do
      attribute :submission_id, :string
      attribute :content_url, :string
      attribute :explanation, :string
      attribute :anonymous, :boolean, default: false
      attribute :name, :string
      attribute :email, :string
      attribute :declaration, :boolean

      before_validation do
        self.submission_id = submission_id.to_s.downcase
        self.content_url = content_url.to_s.strip
        self.explanation = explanation.to_s.strip
        self.name = anonymous ? nil : name.to_s.strip
        self.email = anonymous ? nil : email.to_s.strip.downcase
      end

      validates :submission_id, format: { with: /\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/ }
      validates :content_url, presence: true, length: { maximum: 2048 }
      validates :explanation, length: { minimum: 50, maximum: 20_000 }
      validates :declaration, inclusion: { in: [true] }
      validates :anonymous, inclusion: { in: [true, false] }
      validates :name, presence: true, length: { maximum: 200 }, unless: :anonymous
      validates :email, presence: true, length: { maximum: 254 }, unless: :anonymous
      validate :valid_content_url
      validate :valid_email

      def fingerprint
        Digest::SHA256.hexdigest(
          slice(:content_url, :explanation, :anonymous, :name, :email, :declaration).to_json,
        )
      end

      def summary(reference:, plain_text: false)
        reporter =
          if anonymous
            I18n.t("dsa_notice.anonymous")
          elsif plain_text
            "#{name} (#{email})"
          else
            "#{escaped(name)} ([#{escaped(email)}](mailto:#{ERB::Util.url_encode(email)}))"
          end
        I18n.t(
          "dsa_notice.summary",
          reference:,
          content_url: plain_text ? content_url : "<#{ERB::Util.html_escape(content_url)}>",
          explanation: plain_text ? explanation : escaped(explanation),
          reporter:,
        )
      end

      private

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

      def escaped(value)
        ERB::Util
          .html_escape(value)
          .gsub(/[\\`*_{}\[\]()#+.!|~:\/-]/) { |character| "\\#{character}" }
          .gsub("@", "&#64;")
      end
    end

    policy :enabled
    lock :submission_id do
      transaction { model :topic, :persist_notice }
      policy :matches_submission
    end

    try do
      only_if(:group_notifications_pending) { step :enqueue_group_notifications }
      only_if(:receipt_pending) { step :enqueue_receipt }
    end

    private

    def enabled
      SiteSetting.dsa_reporting_enabled
    end

    def persist_notice(params:)
      existing =
        TopicCustomField.where("char_length(value) < 400").find_by(
          name: "dsa_notice_submission",
          value: params.submission_id,
        )
      return Topic.with_deleted.find_by(id: existing.topic_id) if existing

      group = Group.find_by(id: SiteSetting.dsa_notice_group)
      group = Group[:admins] if !group || !group.users.exists?
      reference = "DSA-#{SecureRandom.hex(8).upcase}"
      summary = params.summary(reference:)
      post =
        PostCreator.create!(
          Discourse.system_user,
          title: I18n.t("dsa_notice.subject", reference:),
          raw: "#{summary}\n\n#{I18n.t("dsa_notice.staff_guidance")}",
          archetype: Archetype.private_message,
          target_group_names: group.name,
          skip_validations: true,
          skip_jobs: true,
        )
      topic = post.topic
      topic.custom_fields["dsa_notice_submission"] = params.submission_id
      topic.custom_fields["dsa_notice"] = {
        "reference" => reference,
        "fingerprint" => params.fingerprint,
        "summary" => summary,
        "text_summary" => params.summary(reference:, plain_text: true),
        "email" => params.email,
      }
      topic.save_custom_fields
      topic
    end

    def matches_submission(params:, topic:)
      topic.custom_fields["dsa_notice"]["fingerprint"] == params.fingerprint
    end

    def group_notifications_pending(topic:)
      !TopicCustomField.exists?(topic_id: topic.id, name: "dsa_notice_group_queued", value: "t")
    end

    def enqueue_group_notifications(topic:)
      DistributedMutex.synchronize("dsa-notice-group-#{topic.id}") do
        unless TopicCustomField.exists?(
                 topic_id: topic.id,
                 name: "dsa_notice_group_queued",
                 value: "t",
               )
          PostJobsEnqueuer.new(topic.first_post, topic, true).enqueue_jobs
          topic.upsert_custom_fields("dsa_notice_group_queued" => "t")
        end
      end
    end

    def receipt_pending(topic:)
      topic.custom_fields["dsa_notice"]["email"].present? &&
        !TopicCustomField.exists?(topic_id: topic.id, name: "dsa_notice_receipt_sent", value: "t")
    end

    def enqueue_receipt(topic:)
      Jobs.enqueue(:dsa_notice_receipt, topic_id: topic.id)
    end
  end
end

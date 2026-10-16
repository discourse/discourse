# frozen_string_literal: true

module Dsa
  class Notice < ActiveRecord::Base
    self.table_name = "dsa_notices"

    CONTENT_FIELDS = %w[content_url explanation anonymous name email declaration].freeze
    private_constant :CONTENT_FIELDS

    belongs_to :post, -> { with_deleted }

    attribute :reference, :string, default: -> { "DSA-#{SecureRandom.hex(8).upcase}" }

    def self.create_with_post!(attributes:, group:)
      notice = new(attributes)
      transaction do
        notice.post =
          PostCreator.create!(
            Discourse.system_user,
            title: I18n.t("dsa_notice.subject", reference: notice.reference),
            raw: notice.raw,
            archetype: Archetype.private_message,
            target_group_names: group.name,
            skip_validations: true,
            skip_jobs: true,
          )
        notice.save!
      end
      notice
    end

    def matches?(submitted_attributes)
      attributes.slice(*CONTENT_FIELDS) ==
        submitted_attributes.stringify_keys.slice(*CONTENT_FIELDS)
    end

    def group_notified?
      group_notified_at.present?
    end

    def receipt_sent?
      receipt_sent_at.present?
    end

    def mark_group_notified!
      update!(group_notified_at: Time.current)
    end

    def mark_receipt_sent!
      update!(receipt_sent_at: Time.current)
    end

    def summary(plain_text: false)
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
        content_url: plain_text ? content_url : "<#{content_url}>",
        explanation: plain_text ? explanation : escaped(explanation),
        reporter:,
      )
    end

    def raw
      "#{summary}\n\n#{I18n.t("dsa_notice.staff_guidance")}"
    end

    private

    def escaped(value)
      ERB::Util.html_escape(
        value.gsub(/[\\`*_{}\[\]()#+.!|~=:\/-]/) { |character| "\\#{character}" },
      ).gsub("@", "&#64;")
    end
  end
end

# == Schema Information
#
# Table name: dsa_notices
#
#  id                :bigint           not null, primary key
#  anonymous         :boolean          default(FALSE), not null
#  content_url       :text             not null
#  declaration       :boolean          not null
#  email             :string
#  explanation       :text             not null
#  group_notified_at :datetime
#  name              :string
#  receipt_sent_at   :datetime
#  reference         :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  post_id           :bigint           not null
#  submission_id     :uuid             not null
#
# Indexes
#
#  index_dsa_notices_on_post_id        (post_id) UNIQUE
#  index_dsa_notices_on_reference      (reference) UNIQUE
#  index_dsa_notices_on_submission_id  (submission_id) UNIQUE
#

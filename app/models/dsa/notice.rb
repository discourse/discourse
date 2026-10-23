# frozen_string_literal: true

module Dsa
  class Notice < ActiveRecord::Base
    self.table_name = "dsa_notices"

    belongs_to :post, -> { with_deleted }, optional: true

    def self.create_with_post!(attributes:, group:)
      transaction do
        notice = create!(attributes)
        notice.post =
          PostCreator.create!(
            Discourse.system_user,
            title: I18n.t("dsa_notice.subject", reference: notice.reference),
            raw: notice.summary,
            archetype: Archetype.private_message,
            target_group_names: group.name,
            skip_validations: true,
            skip_jobs: true,
          )
        notice.save!
        notice
      end
    end

    def reference
      "DSA-#{id}"
    end

    def receipt_sent?
      receipt_sent_at.present?
    end

    def mark_receipt_sent!
      update!(receipt_sent_at: Time.current)
    end

    def summary(plain_text: false)
      reporter_email =
        if plain_text
          email
        else
          "[#{escaped(email)}](mailto:#{ERB::Util.url_encode(email)})"
        end
      I18n.t(
        "dsa_notice.summary",
        reference:,
        content_url: plain_text ? content_url : "<#{content_url}>",
        explanation: plain_text ? explanation : escaped(explanation),
        reporter_email:,
        reporter_name: plain_text ? name : escaped(name),
      )
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
#  id              :bigint           not null, primary key
#  content_url     :text             not null
#  email           :string
#  explanation     :text             not null
#  name            :string
#  receipt_sent_at :datetime
#  created_at      :datetime         not null
#  post_id         :bigint
#
# Indexes
#
#  index_dsa_notices_on_post_id  (post_id) UNIQUE
#

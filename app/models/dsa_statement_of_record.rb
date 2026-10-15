# frozen_string_literal: true

class DsaStatementOfRecord < ActiveRecord::Base
  TERRITORIAL_SCOPE = %w[
    AT
    BE
    BG
    CY
    CZ
    DE
    DK
    EE
    ES
    FI
    FR
    GR
    HR
    HU
    IE
    IS
    IT
    LI
    LT
    LU
    LV
    MT
    NL
    NO
    PL
    PT
    RO
    SE
    SI
    SK
  ].freeze

  enum :status, { pending: 0, ready: 1 }

  CATEGORIES =
    %w[
      ANIMAL_WELFARE
      CONSUMER_INFORMATION
      CYBER_VIOLENCE
      CYBER_VIOLENCE_AGAINST_WOMEN
      DATA_PROTECTION_AND_PRIVACY_VIOLATIONS
      ILLEGAL_OR_HARMFUL_SPEECH
      INTELLECTUAL_PROPERTY_INFRINGEMENTS
      NEGATIVE_EFFECTS_ON_CIVIC_DISCOURSE_OR_ELECTIONS
      NOT_SPECIFIED_NOTICE
      OTHER_VIOLATION_TC
      PROTECTION_OF_MINORS
      RISK_FOR_PUBLIC_SECURITY
      SCAMS_AND_FRAUD
      SELF_HARM
      UNSAFE_AND_PROHIBITED_PRODUCTS
      VIOLENCE
    ].map { |category| "STATEMENT_CATEGORY_#{category}" }.freeze

  class << self
    def community_rules
      JSON
        .parse(SiteSetting.dsa_community_rules)
        .map do |rule|
          rule.merge(
            "id" => Digest::SHA256.hexdigest([rule["ground"], rule["explanation"]].to_json),
          )
        end
    end

    def classification_enabled?
      SiteSetting.dsa_reporting_enabled && JSON.parse(SiteSetting.dsa_community_rules).present?
    end
  end

  def classify!(community_rule:, category:, classified_by:)
    update!(
      payload:
        payload.merge(
          "incompatible_content_ground" => community_rule.fetch("ground"),
          "incompatible_content_explanation" => community_rule.fetch("explanation"),
          "category" => category,
        ),
      status: :ready,
      classified_by_id: classified_by.id,
      classified_at: Time.current,
    )
  end
end

# == Schema Information
#
# Table name: dsa_statement_of_records
#
#  id               :uuid             not null, primary key
#  classified_at    :datetime
#  payload          :jsonb            not null
#  status           :integer          default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  classified_by_id :bigint
#  reviewable_id    :bigint           not null
#
# Indexes
#
#  index_dsa_statement_of_records_on_reviewable_id  (reviewable_id)
#

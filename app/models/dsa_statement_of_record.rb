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

  enum :status, { pending: 0 }
end

# == Schema Information
#
# Table name: dsa_statement_of_records
#
#  id            :uuid             not null, primary key
#  payload       :jsonb            not null
#  status        :integer          default("pending"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  reviewable_id :bigint           not null
#
# Indexes
#
#  index_dsa_statement_of_records_on_reviewable_id  (reviewable_id)
#

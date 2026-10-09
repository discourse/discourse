# frozen_string_literal: true

class DsaStatementOfRecord < ActiveRecord::Base
  belongs_to :reviewable, optional: true

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

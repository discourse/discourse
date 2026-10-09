# frozen_string_literal: true
class DsaStatementOfRecord < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :recipient, class_name: "User", optional: true

  enum :status, { pending: 0 }

  def reverse!
    with_lock do
      attributes = { reversed_at: Time.zone.now }
      if payload["decision_visibility"]
        attributes[:payload] = payload.merge(
          "end_date_visibility_restriction" => Time.zone.today.iso8601,
        )
      end
      update!(attributes)
    end
  end
end

# == Schema Information
#
# Table name: dsa_statement_of_records
#
#  id            :bigint           not null, primary key
#  action_name   :string           not null
#  content       :jsonb            not null
#  decision_key  :string           not null
#  payload       :jsonb            not null
#  puid          :string           not null
#  reversed_at   :datetime
#  status        :integer          default("pending"), not null
#  target_type   :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  actor_id      :integer
#  recipient_id  :integer
#  reviewable_id :bigint           not null
#  target_id     :bigint           not null
#
# Indexes
#
#  idx_on_reviewable_id_decision_key_08233caf4d  (reviewable_id,decision_key)
#  index_dsa_records_on_decision_and_target      (decision_key,target_type,target_id) UNIQUE
#  index_dsa_statement_of_records_on_puid        (puid) UNIQUE
#

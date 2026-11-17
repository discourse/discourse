# frozen_string_literal: true

class AiArtifactShareKeyValue < ActiveRecord::Base
  belongs_to :ai_artifact_share
  belongs_to :user

  validates :key, presence: true, length: { maximum: 50 }
  validates :value,
            presence: true,
            length: {
              maximum: ->(_) { SiteSetting.ai_artifact_kv_value_max_length },
            }
  attribute :public, :boolean, default: false
  validates :key, uniqueness: { scope: %i[ai_artifact_share_id user_id] }
  validate :validate_max_keys_per_user_per_share

  private

  def validate_max_keys_per_user_per_share
    return unless ai_artifact_share_id && user_id

    count = self.class.where(ai_artifact_share_id: ai_artifact_share_id, user_id: user_id).count
    count -= 1 if persisted?
    if count >= SiteSetting.ai_artifact_max_keys_per_user_per_artifact
      errors.add(
        :base,
        I18n.t(
          "discourse_ai.ai_artifact.errors.max_keys_exceeded",
          count: SiteSetting.ai_artifact_max_keys_per_user_per_artifact,
        ),
      )
    end
  end
end

# == Schema Information
#
# Table name: ai_artifact_share_key_values
#
#  id                   :bigint           not null, primary key
#  key                  :string(50)       not null
#  public               :boolean          default(FALSE), not null
#  value                :string(20000)    not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  ai_artifact_share_id :bigint           not null
#  user_id              :integer          not null
#
# Indexes
#
#  index_ai_artifact_share_key_values_on_user_id  (user_id)
#  index_ai_artifact_share_kv_unique              (ai_artifact_share_id,user_id,key) UNIQUE
#

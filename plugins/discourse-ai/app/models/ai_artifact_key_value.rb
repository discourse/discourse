# frozen_string_literal: true

class AiArtifactKeyValue < ActiveRecord::Base
  belongs_to :ai_artifact
  belongs_to :user

  validates :key, presence: true, length: { maximum: 50 }
  validates :value,
            presence: true,
            length: {
              maximum: ->(_) { SiteSetting.ai_artifact_kv_value_max_length },
            }
  attribute :public, :boolean, default: false
  validates :ai_artifact, presence: true
  validates :user, presence: true
  validates :key, uniqueness: { scope: %i[ai_artifact_id user_id] }

  validate :validate_max_keys_per_user_per_artifact

  private

  def validate_max_keys_per_user_per_artifact
    return unless ai_artifact_id && user_id

    max_keys = SiteSetting.ai_artifact_max_keys_per_user_per_artifact
    existing_count = self.class.where(ai_artifact_id: ai_artifact_id, user_id: user_id).count

    # Don't count the current record if it's being updated
    existing_count -= 1 if persisted?

    if existing_count >= max_keys
      errors.add(
        :base,
        I18n.t("discourse_ai.ai_artifact.errors.max_keys_exceeded", count: max_keys),
      )
    end
  end
end

# == Schema Information
#
# Table name: ai_artifact_key_values
#
#  id             :bigint           not null, primary key
#  ai_artifact_id :bigint           not null
#  user_id        :integer          not null
#  key            :string(50)       not null
#  value          :string(20000)    not null
#  public         :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_ai_artifact_kv_unique  (ai_artifact_id,user_id,key) UNIQUE
#

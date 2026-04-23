# frozen_string_literal: true

class WebArtifactKeyValue < ActiveRecord::Base
  belongs_to :web_artifact
  belongs_to :user

  validates :key, presence: true, length: { maximum: 50 }
  validates :value,
            presence: true,
            length: {
              maximum: ->(_) { SiteSetting.web_artifact_kv_value_max_length },
            }
  attribute :public, :boolean, default: false
  validates :web_artifact, presence: true
  validates :user, presence: true
  validates :key, uniqueness: { scope: %i[web_artifact_id user_id] }

  validate :validate_max_keys_per_user_per_artifact

  private

  def validate_max_keys_per_user_per_artifact
    return unless web_artifact_id && user_id

    max_keys = SiteSetting.web_artifact_max_keys_per_user_per_artifact
    existing_count = self.class.where(web_artifact_id: web_artifact_id, user_id: user_id).count

    existing_count -= 1 if persisted?

    if existing_count >= max_keys
      errors.add(:base, I18n.t("web_artifact.errors.max_keys_exceeded", count: max_keys))
    end
  end
end

# == Schema Information
#
# Table name: web_artifact_key_values
#
#  id              :bigint           not null, primary key
#  key             :string(50)       not null
#  public          :boolean          default(FALSE), not null
#  value           :string(20000)    not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :integer          not null
#  web_artifact_id :bigint           not null
#
# Indexes
#
#  index_web_artifact_kv_unique  (web_artifact_id,user_id,key) UNIQUE
#

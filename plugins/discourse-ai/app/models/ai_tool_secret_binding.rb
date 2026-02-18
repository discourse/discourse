# frozen_string_literal: true

class AiToolSecretBinding < ActiveRecord::Base
  belongs_to :ai_tool
  belongs_to :ai_secret
  belongs_to :created_by, class_name: "User", optional: true

  validates :alias,
            presence: true,
            length: {
              maximum: 100,
            },
            format: {
              with: AiTool::SECRET_ALIAS_PATTERN,
              message: I18n.t("discourse_ai.tools.name.characters"),
            },
            uniqueness: {
              scope: :ai_tool_id,
            }
  validates :ai_secret_id, presence: true

  validate :secret_exists
  validate :alias_declared

  private

  def secret_exists
    return if ai_secret_id.blank?
    return if AiSecret.exists?(ai_secret_id)

    errors.add(:ai_secret_id, I18n.t("discourse_ai.tools.secret_bindings.secret_not_found"))
  end

  def alias_declared
    return if self[:alias].blank? || ai_tool.blank?
    return if ai_tool.secret_contract_for(self[:alias]).present?

    errors.add(
      :alias,
      I18n.t("discourse_ai.tools.secret_bindings.alias_not_declared", alias: self[:alias]),
    )
  end
end

# == Schema Information
#
# Table name: ai_tool_secret_bindings
#
#  id            :bigint           not null, primary key
#  alias         :string(100)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ai_secret_id  :bigint           not null
#  ai_tool_id    :bigint           not null
#  created_by_id :integer
#
# Indexes
#
#  index_ai_tool_secret_bindings_on_ai_secret_id          (ai_secret_id)
#  index_ai_tool_secret_bindings_on_ai_tool_id            (ai_tool_id)
#  index_ai_tool_secret_bindings_on_ai_tool_id_and_alias  (ai_tool_id,alias) UNIQUE
#

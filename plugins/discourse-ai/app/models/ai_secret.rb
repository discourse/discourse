# frozen_string_literal: true

class AiSecret < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :secret, presence: true

  has_many :llm_models, dependent: :nullify
  has_many :embedding_definitions, dependent: :nullify

  def in_use?
    llm_models.exists? || embedding_definitions.exists? || used_by_provider_params?
  end

  def used_by
    usage = []
    llm_models.each { |llm| usage << { type: "llm", name: llm.display_name, id: llm.id } }
    embedding_definitions.each do |ed|
      usage << { type: "embedding", name: ed.display_name, id: ed.id }
    end
    provider_param_llms.each do |llm|
      usage << { type: "llm_provider_param", name: llm.display_name, id: llm.id }
    end
    usage
  end

  private

  def used_by_provider_params?
    provider_param_llms.exists?
  end

  def provider_param_llms
    secret_keys =
      LlmModel.provider_params.flat_map do |provider, params|
        params.filter_map { |key, type| [provider, key] if type == :secret }
      end

    return LlmModel.none if secret_keys.empty?

    sql_conditions = []
    bind_values = []

    secret_keys.each do |provider, key|
      sql_conditions << "(provider = ? AND provider_params ->> ? = ?)"
      bind_values << provider.to_s << key.to_s << id.to_s
    end

    LlmModel.where(sql_conditions.join(" OR "), *bind_values).where("llm_models.id > 0")
  end
end

# == Schema Information
#
# Table name: ai_secrets
#
#  id            :bigint           not null, primary key
#  name          :string(100)      not null
#  secret        :string           not null
#  created_by_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

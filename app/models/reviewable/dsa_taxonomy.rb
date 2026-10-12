# frozen_string_literal: true

class Reviewable::DsaTaxonomy
  ILLEGAL_CONTENT = "DECISION_GROUND_ILLEGAL_CONTENT"
  INCOMPATIBLE_CONTENT = "DECISION_GROUND_INCOMPATIBLE_CONTENT"
  OTHER_KEYWORD = "KEYWORD_OTHER"
  OTHER_KEYWORD_MAX_LENGTH = 500

  def self.data
    @data ||= YAML.safe_load_file(Rails.root.join("config/dsa_taxonomy.yml")).freeze
  end

  def self.legal_basis_for(category)
    data.find { |_legal_basis, categories| categories.key?(category) }&.first
  end

  def self.incompatible_content_category
    data[INCOMPATIBLE_CONTENT].keys.first
  end

  def self.keywords_for(category)
    data.dig(legal_basis_for(category), category)
  end
end

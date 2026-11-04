# frozen_string_literal: true

class DsaStatementOfRecord::ClassificationContract < Service::ContractBase
  attribute :community_rule, :string
  attribute :category, :string

  validates :community_rule, presence: true
  validates :category, inclusion: { in: DsaStatementOfRecord::CATEGORIES }

  def rule
    DsaStatementOfRecord.community_rules.find do |entry|
      entry[DsaStatementOfRecord::COMMUNITY_RULE_ID_KEY] == community_rule
    end
  end
end

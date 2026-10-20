# frozen_string_literal: true

class DsaClassificationSerializer < ApplicationSerializer
  attributes :community_rules, :categories

  def community_rules
    DsaStatementOfRecord.community_rules.map { |rule| rule.slice("id", "ground") }
  end

  def categories
    DsaStatementOfRecord::CATEGORIES.map do |category|
      { id: category, name: I18n.t("dsa_statements.categories.#{category}") }
    end
  end

  def include_community_rules?
    scope.is_staff? && DsaStatementOfRecord.classification_enabled?
  end

  alias_method :include_categories?, :include_community_rules?
end

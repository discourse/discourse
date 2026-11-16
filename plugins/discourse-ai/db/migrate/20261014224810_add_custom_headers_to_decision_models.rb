# frozen_string_literal: true
class AddCustomHeadersToDecisionModels < ActiveRecord::Migration[8.1]
  def change
    add_column :decision_models, :custom_headers, :jsonb, default: [], null: false
  end
end

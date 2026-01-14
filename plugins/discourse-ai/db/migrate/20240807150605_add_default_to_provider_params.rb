# frozen_string_literal: true
class AddDefaultToProviderParams < ActiveRecord::Migration[7.1]
  def change
    change_column_default :llm_models, :provider_params, from: nil, to: {}
  end
end

# frozen_string_literal: true
class AddApiKeyToDecisionModels < ActiveRecord::Migration[8.1]
  def change
    # Seeded models carry their key directly so it never appears in the admin secrets list.
    add_column :decision_models, :api_key, :string
  end
end

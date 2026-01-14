# frozen_string_literal: true

class AddEndpointDataToLlmModel < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_models, :url, :string
    add_column :llm_models, :api_key, :string
  end
end

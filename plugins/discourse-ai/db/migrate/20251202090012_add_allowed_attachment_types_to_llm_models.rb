# frozen_string_literal: true

class AddAllowedAttachmentTypesToLlmModels < ActiveRecord::Migration[7.0]
  def up
    add_column :llm_models, :allowed_attachment_types, :text, array: true, default: [], null: false
  end

  def down
    remove_column :llm_models, :allowed_attachment_types
  end
end

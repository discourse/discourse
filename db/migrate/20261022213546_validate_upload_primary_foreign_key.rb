# frozen_string_literal: true

class ValidateUploadPrimaryForeignKey < ActiveRecord::Migration[8.1]
  def change
    up_only { validate_foreign_key :uploads, :uploads, column: :primary_upload_id }
  end
end

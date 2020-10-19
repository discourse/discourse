# frozen_string_literal: true

class AddAnimatedToUploads < ActiveRecord::Migration[6.0]
  def change
    add_column :uploads, :animated, :boolean
  end
end

# frozen_string_literal: true

class AddTextSizeSeqToUserOption < ActiveRecord::Migration[5.2]
  def change
    add_column :user_options, :text_size_seq, :integer, null: false, default: 0
  end
end

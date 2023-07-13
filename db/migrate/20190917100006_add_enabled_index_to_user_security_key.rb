# frozen_string_literal: true

class AddEnabledIndexToUserSecurityKey < ActiveRecord::Migration[6.0]
  def change
    add_index :user_security_keys, %i[factor_type enabled]
  end
end

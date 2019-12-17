# frozen_string_literal: true

require "common_passwords/common_passwords"

class ClearCommonPasswordsCache < ActiveRecord::Migration[4.2]
  def change
    Discourse.redis.without_namespace.del CommonPasswords::LIST_KEY
  end
end

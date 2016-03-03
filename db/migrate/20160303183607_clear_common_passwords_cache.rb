require "common_passwords/common_passwords"

class ClearCommonPasswordsCache < ActiveRecord::Migration
  def change
    $redis.without_namespace.del CommonPasswords::LIST_KEY
  end
end

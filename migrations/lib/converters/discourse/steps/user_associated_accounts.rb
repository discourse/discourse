# frozen_string_literal: true

module Migrations::Converters::Discourse
  class UserAssociatedAccounts < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM user_associated_accounts
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM user_associated_accounts
        WHERE user_id >= 0
        ORDER BY id
      SQL
    end

    def process_item(item)
      IntermediateDB::UserAssociatedAccount.create(
        provider_name: item[:provider_name],
        user_id: item[:user_id],
        created_at: item[:created_at],
        info: item[:info],
        last_used: item[:last_used],
        provider_uid: item[:provider_uid],
      )
    end
  end
end

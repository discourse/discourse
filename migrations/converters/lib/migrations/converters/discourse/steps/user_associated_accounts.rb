# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class UserAssociatedAccounts < Conversion::Step
        source { reads_table "user_associated_accounts", where: "user_id > 0" }

        processor do
          def process(item)
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
    end
  end
end

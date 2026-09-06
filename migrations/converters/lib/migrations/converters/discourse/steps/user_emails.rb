# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class UserEmails < Conversion::Step
        source { reads_table "user_emails", where: "user_id > 0" }

        processor do
          def process(item)
            IntermediateDB::UserEmail.create(
              email: item[:email],
              primary: item[:primary],
              user_id: item[:user_id],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end

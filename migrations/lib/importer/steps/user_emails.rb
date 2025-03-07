# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserEmails < ::Migrations::Importer::Step
    depends_on :users

    def execute
      puts "Importing user_emails"
    end
  end
end

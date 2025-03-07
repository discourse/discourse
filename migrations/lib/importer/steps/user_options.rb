# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserOptions < ::Migrations::Importer::Step
    depends_on :users

    def execute
      puts "Importing user_options"
    end
  end
end

# frozen_string_literal: true

module Migrations::CLI::UploadCommand
  def self.included(thor)
    thor.class_eval do
      desc "upload", "Upload a file"
      def upload
        Migrations.load_rails_environment

        puts "Uploading..."
      end
    end
  end
end

# frozen_string_literal: true

module Migrations
  module CLI
    class ExceptionHandler
      def self.handle_and_exit(&block)
        block.call
      rescue ClassFilter::UnknownClassNamesError => e
        handle_unknown_class_names_error(e)
        exit(1)
      rescue => e
        puts "An error occurred: #{e.message}".red
        puts e.backtrace.join("\n")
        exit(1)
      end

      private

      def self.handle_unknown_class_names_error(error)
        all_suggestions_found = true

        error.missing_names.each do |missing_name|
          suggestions =
            DidYouMean::SpellChecker.new(dictionary: error.available_names).correct(missing_name)
          puts "Unknown step '#{missing_name}'".red
          if suggestions.any?
            puts "Did you mean: #{suggestions.join(", ")}".yellow
          else
            all_suggestions_found = false
          end
        end

        if !all_suggestions_found
          puts "Available steps are: ".yellow + error.available_names.join(", ")
        end
      end
    end
  end
end

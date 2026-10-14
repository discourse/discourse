# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Error < StandardError
        include ::Migrations::CLI::PresentableError
      end
    end
  end
end

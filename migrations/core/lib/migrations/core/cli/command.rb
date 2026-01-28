# frozen_string_literal: true

require "samovar"

module Migrations
  module Core
    module CLI
      class Command < Samovar::Command
        COLORS = {
          green: "\e[32m",
          red: "\e[31m",
          yellow: "\e[33m",
          reset: "\e[0m"
        }.freeze

        def success(message)
          puts "#{COLORS[:green]}✓#{COLORS[:reset]} #{message}"
        end

        def error(message)
          puts "#{COLORS[:red]}✗#{COLORS[:reset]} #{message}"
        end

        def warn(message)
          puts "#{COLORS[:yellow]}!#{COLORS[:reset]} #{message}"
        end
      end
    end
  end
end

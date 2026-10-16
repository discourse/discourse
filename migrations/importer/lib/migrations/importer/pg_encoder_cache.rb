# frozen_string_literal: true

require "json"
require "pg"

module Migrations
  module Importer
    module PgEncoderCache
      @encoders = {}

      # PG::TextEncoder::JSON passes the `quirks_mode` keyword, which the json gem
      # dropped in 3.0; fixed in pg upstream but unreleased as of 1.6.3 — drop
      # this once a fixed pg version is required
      class JsonEncoder < PG::SimpleEncoder
        def encode(value)
          ::JSON.generate(value)
        end
      end

      ENCODER_MAP = {
        "bool" => -> { PG::TextEncoder::Boolean.new },
        "date" => -> { PG::TextEncoder::Date.new },
        "float8" => -> { PG::TextEncoder::Float.new },
        "inet" => -> { PG::TextEncoder::Inet.new },
        "int4" => -> { PG::TextEncoder::Integer.new },
        "int8" => -> { PG::TextEncoder::Integer.new },
        "json" => -> { JsonEncoder.new },
        "jsonb" => -> { JsonEncoder.new },
        "text" => -> { PG::TextEncoder::String.new },
        "timestamp" => -> { PG::TextEncoder::String.new },
        "uuid" => -> { PG::TextEncoder::String.new },
        "varchar" => -> { PG::TextEncoder::String.new },
        "int4range" => -> { PG::TextEncoder::String.new },
        "inet[]" => -> { PG::TextEncoder::Array.new(name: "inet") },
        "int4[]" => -> { PG::TextEncoder::Array.new(name: "int4") },
        "int8[]" => -> { PG::TextEncoder::Array.new(name: "int8") },
        "text[]" => -> { PG::TextEncoder::Array.new(name: "text") },
        "varchar[]" => -> { PG::TextEncoder::Array.new(name: "varchar") },
      }

      def self.get_encoder(pg_type)
        pg_type = normalize_pg_type(pg_type)

        @encoders[pg_type] ||= begin
          factory = ENCODER_MAP[pg_type]
          raise "Unsupported PG type #{pg_type}" unless factory

          factory.call
        end
      end

      def self.normalize_pg_type(pg_type)
        pg_type.start_with?("_") ? "#{pg_type[1..]}[]" : pg_type
      end
    end
  end
end

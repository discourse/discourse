# frozen_string_literal: true

require "openssl"
require "securerandom"

module Migrations
  module Importer
    module Customizations
      module Diff
        # Replaces secret values while rows are read. The replacement is an HMAC
        # with a random per-run key, so equal values get equal tags and changes
        # still show up, but nothing can be recovered from the output.
        class Redactor
          def initialize(secret_setting_names: Set.new, hmac_key: SecureRandom.bytes(32))
            @secret_setting_names = secret_setting_names
            @hmac_key = hmac_key
          end

          def secret_setting_count
            @secret_setting_names.size
          end

          # Settings have `secret: true` flags, so the narrow pattern is enough
          # there; other key/value tables get the broad one.
          FLAGGED_TABLES = %w[site_settings theme_site_settings].freeze

          # @return [Proc, nil] redacts one row of `table`, nil when nothing needs it
          def for(table, columns)
            column_indexes =
              columns.each_index.select { |i| Secrets.secret_column?(table, columns[i]) }

            value_index = columns.index("value")
            name_index = columns.index("name") || columns.index("key")
            name_index = nil if value_index.nil?

            return nil if column_indexes.empty? && name_index.nil?

            flagged = FLAGGED_TABLES.include?(table)

            lambda do |row|
              row = row.dup
              column_indexes.each { |i| row[i] = tag(row[i]) }
              row[value_index] = tag(row[value_index]) if name_index &&
                secret_name?(row[name_index], flagged)
              row
            end
          end

          def tag(value)
            return value if value.nil? || value.empty?
            "[redacted:#{OpenSSL::HMAC.hexdigest("SHA256", @hmac_key, value)[0, 8]}]"
          end

          private

          def secret_name?(name, flagged)
            return false if name.nil?
            return true if Secrets.secret_name?(name) || @secret_setting_names.include?(name)
            !flagged && Secrets.possibly_secret_name?(name)
          end
        end
      end
    end
  end
end

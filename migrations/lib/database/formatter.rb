# frozen_string_literal: true

require "extralite"

module Migrations::Database
  module Formatter
    def self.format_datetime(value)
      value ? value.utc.iso8601 : nil
    end

    def self.format_date(value)
      value ? value.to_date.iso8601 : nil
    end

    def self.format_boolean(value)
      return nil if value.nil?
      value ? 1 : 0
    end

    def self.format_ip_address(value)
      return nil if value.blank?
      begin
        IPAddr.new(value).to_s
      rescue StandardError
        nil
      end
    end

    def self.to_blob(value)
      return nil if value.blank?
      Extralite::Blob.new(value)
    end
  end
end

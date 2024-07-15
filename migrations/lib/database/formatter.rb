# frozen_string_literal: true

require "ipaddr"
require "date"
require "extralite"

module Migrations::Database
  module Formatter
    module_function

    def format_datetime(value)
      value&.utc&.iso8601
    end

    def format_date(value)
      value&.to_date&.iso8601
    end

    def format_boolean(value)
      return nil if value.nil?
      value ? 1 : 0
    end

    def format_ip_address(value)
      return nil if value.blank?
      IPAddr.new(value).to_s
    rescue ArgumentError
      nil
    end

    def to_blob(value)
      return nil if value.blank?
      Extralite::Blob.new(value)
    end
  end
end

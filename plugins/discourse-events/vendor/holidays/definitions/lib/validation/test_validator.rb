require 'date'
require_relative 'error'

module Definitions
  module Validation
    class Test
      def call(tests)
        err!("Tests cannot be nil") if tests.nil?
        err!("Tests cannot be empty. They are too important to leave out!") if tests.empty?
        err!("Tests must be an array") unless tests.is_a?(Array)

        tests.each do |t|
          validate!(t)
        end

        true
      end

      private

      def err!(msg)
        raise Errors::InvalidTest.new(msg)
      end

      def validate!(t)
        validate_given!(t["given"])
        validate_expect!(t["expect"])
      rescue Errors::InvalidTest => e
        raise Errors::InvalidTest.new("#{e.message} - #{t.inspect}")
      end

      def validate_given!(g)
        err!("Test must contain given key") if g.nil?

        validate_regions!(g["regions"])
        validate_options!(g["options"])
        validate_date_values!(g)
      end

      def validate_regions!(regions)
        err!("Test contains invalid regions (must be an array of strings)") unless regions.is_a?(Array)
        err!("Test must contain at least one region") if regions.nil? || regions.empty?

        regions.each do |r|
          err!("Test cannot contain empty regions") if r.empty?
        end
      end

      def validate_options!(opts)
        if opts
          opts = [ opts ] unless opts.is_a?(Array)
          opts.each do |opt|
            err!("Test contains invalid option(s)") unless opt == "informal" || opt == "observed"
          end
        end
      end

      def validate_date_values!(given)
        err!("Test must contain some date") unless given.has_key?("date")

        given["date"] = [ given["date"] ] unless given["date"].is_a?(Array)

        given["date"].each do |d|
          parse_date!(d)
        end
      end

      def parse_date!(d)
        DateTime.parse(d)
      rescue TypeError, ArgumentError, NoMethodError
        err!("Test must contain valid date, date value was: '#{d}")
      end

      def validate_expect!(e)
        err!("Test must contain expect key") if e.nil?

        if e.has_key?("holiday") && ![true, false].include?(e["holiday"])
          err!("Test contains invalid holiday value (must be true/false)")
        end
      end
    end
  end
end

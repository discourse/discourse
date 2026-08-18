module Holidays
  module CoreExtensions
    module Date
      def self.included(base)
        base.extend ClassMethods
      end

      # Get holidays on the current date.
      #
      # Returns an array of hashes or nil. See Holidays#between for options
      # and the output format.
      #
      #   Date.civil('2008-01-01').holidays(:ca_)
      #   => [{:name => 'New Year\'s Day',...}]
      #
      # Also available via Holidays#on.
      def holidays(*options)
        Holidays.on(self, *options)
      end

      # Check if the current date is a holiday.
      #
      # Returns true or false.
      #
      #   Date.civil('2008-01-01').holiday?(:ca)
      #   => true
      def holiday?(*options)
        holidays = self.holidays(*options)
        holidays && !holidays.empty?
      end

      # Returns a new Date where one or more of the elements have been changed according to the +options+ parameter.
      # The +options+ parameter is a hash with a combination of these keys: <tt>:year</tt>, <tt>:month</tt>, <tt>:day</tt>.
      #
      #   Date.new(2007, 5, 12).change(day: 1)               # => Date.new(2007, 5, 1)
      #   Date.new(2007, 5, 12).change(year: 2005, month: 1) # => Date.new(2005, 1, 12)
      def change(options)
        ::Date.new(
          options.fetch(:year, year),
          options.fetch(:month, month),
          options.fetch(:day, day)
        )
      end

      def end_of_month
        last_day = ::Time.days_in_month( self.month, self.year )
        change(:day => last_day)
      end

      module ClassMethods
        def calculate_mday(year, month, week, wday)
          Holidays::Factory::DateCalculator.day_of_month_calculator.call(year, month, week, wday)
        end
      end
    end
  end
end

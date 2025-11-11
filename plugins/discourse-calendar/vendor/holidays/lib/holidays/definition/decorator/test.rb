module Holidays
  module Definition
    module Decorator
      class Test
        def call(t)
          src = ""

          t.dates.each do |d|
            date = "Date.civil(#{d.year}, #{d.month}, #{d.day})"

            holiday_call = "Holidays.on(#{date}, #{t.regions}"

            if t.options
              holiday_call += ", #{decorate_options(t.options)}"
            end

            if t.holiday?
              src += "assert_equal \"#{t.name}\", (#{holiday_call})[0] || {})[:name]\n"
            else
              src += "assert_nil (#{holiday_call})[0] || {})[:name]\n"
            end
          end

          src
        end

        private

        def decorate_options(options)
          options.map do |o|
            o.to_sym
          end
        end
      end
    end
  end
end

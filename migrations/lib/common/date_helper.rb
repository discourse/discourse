# frozen_string_literal: true

module Migrations
  module DateHelper
    # based on code from https://gist.github.com/emmahsax/af285a4b71d8506a1625a3e591dc993b
    def self.human_readable_time(secs)
      return "< 1 second" if secs < 1

      [[60, :seconds], [60, :minutes], [24, :hours], [Float::INFINITY, :days]].map do |count, name|
          next if secs <= 0

          secs, number = secs.divmod(count)
          unless number.to_i == 0
            "#{number.to_i} #{number == 1 ? name.to_s.delete_suffix("s") : name}"
          end
        end
        .compact
        .reverse
        .join(", ")
    end
  end
end

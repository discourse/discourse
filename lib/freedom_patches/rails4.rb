# frozen_string_literal: true

module FreedomPatches
  module Rails4
    def self.distance_of_time_in_words(*args)
      Discourse.deprecate(
        "FreedomPatches::Rails4.distance_of_time_in_words has moved to AgeWords.distance_of_time_in_words",
        output_in_test: true,
        since: "3.1.0.beta5",
        drop_from: "3.2.0.beta1",
      )

      AgeWords.distance_of_time_in_words(*args)
    end

    def self.time_ago_in_words(*args)
      Discourse.deprecate(
        "FreedomPatches::Rails4.time_ago_in_words has moved to AgeWords.time_ago_in_words",
        output_in_test: true,
        since: "3.1.0.beta5",
        drop_from: "3.2.0.beta1",
      )

      AgeWords.time_ago_in_words(*args)
    end
  end
end

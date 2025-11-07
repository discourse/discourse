# frozen_string_literal: true

module DiscourseAi
  module Evals
    module Runners
      class Spam
        def self.can_handle?(full_feature_name)
          feature_name.starts_with?("spam:")
        end

        def initialize(feature_name)
          @feature_name = feature_name
        end

        def run(eval_case, llm)
        end

        private

        attr_reader :feature_name
      end
    end
  end
end

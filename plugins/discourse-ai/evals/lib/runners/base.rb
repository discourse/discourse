# frozen_string_literal: true

module DiscourseAi
  module Evals
    module Runners
      class Base
        class << self
          def can_handle?(_feature)
            raise NotImplemented
          end

          def find_runner(feature)
            registry = [
              DiscourseAi::Evals::Runners::AiHelper,
              DiscourseAi::Evals::Runners::Spam,
              DiscourseAi::Evals::Runners::Summarization,
            ]
            klass = registry.find { |runner| runner.can_handle?(feature) }
            klass&.new(feature.split(":").last) if klass
          end
        end

        attr_reader :feature

        def initialize(feature)
          @feature = feature
        end
      end
    end
  end
end

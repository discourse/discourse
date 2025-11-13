# frozen_string_literal: true

module DiscourseAi
  module Evals
    module RunnerSpecHelper
      def stub_runner_bot(
        persona: instance_double(DiscourseAi::Personas::Persona, response_format: nil),
        response: "ok",
        &custom_block
      )
        bot_double = instance_double(DiscourseAi::Personas::Bot, persona: persona)

        allow(AiPersona).to receive(:find_by_id_from_cache).and_return(nil)
        allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)

        if block_given?
          allow(bot_double).to receive(:reply) { |*_, &blk| custom_block.call(blk) }
        else
          allow(bot_double).to receive(:reply) { |_ctx, &blk| blk.call(response, nil, nil) }
        end

        bot_double
      end
    end
  end
end

RSpec.configure { |config| config.include DiscourseAi::Evals::RunnerSpecHelper }

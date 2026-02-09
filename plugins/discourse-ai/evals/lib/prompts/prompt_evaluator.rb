# frozen_string_literal: true

class DiscourseAi::Evals::PromptEvaluator
  def initialize(llm_model)
    @llm = llm_model.to_llm
  end

  def prompt_call(args)
    args = [args] if !args.is_a?(Array)
    runner = DiscourseAi::Evals::PromptSingleTestRunner.new(@llm)

    with_tests_progress(total: args.size) do |bump_progress|
      args.flat_map do |test|
        bump_progress.call

        prompts = test[:prompts] || [test[:prompt]]
        messages = test[:messages] || [test[:message]]
        followups = symbolize_followups(test)
        output_thinking = test[:output_thinking] || false
        stream = test[:stream] || false
        temperature = test[:temperature]
        tools = symbolize_tools(test[:tools])
        tool_results = test[:tool_results]
        chain_length = test[:chain_length] || 1
        max_tool_calls = test[:max_tool_calls]

        prompts.flat_map do |prompt|
          messages.map do |message|
            runner.run_single_test(
              prompt:,
              message:,
              followups:,
              output_thinking:,
              stream:,
              temperature:,
              tools:,
              tool_results:,
              chain_length:,
              max_tool_calls:,
            )
          end
        end
      end
    end
  end

  private

  def symbolize_followups(args)
    return nil if args[:followups].nil? && args[:followup].nil?
    followups = args[:followups] || [args[:followup]]
    followups.map do |followup|
      followup = followup.dup.symbolize_keys!
      message = followup[:message].dup.symbolize_keys!
      message[:type] = message[:type].to_sym if message[:type]
      followup[:message] = message
      followup
    end
  end

  def symbolize_tools(tools)
    return nil if tools.nil?
    tools.map do |tool|
      tool.symbolize_keys!
      tool.merge(
        parameters: tool[:parameters]&.map { |param| param.transform_keys(&:to_sym) },
      ).compact
    end
  end

  def with_tests_progress(total:)
    puts ""
    count = 0
    result =
      yield(
        -> do
          count += 1
          print "\rProcessing test #{count}/#{total}"
        end
      )
    print "\r\033[K"
    result
  end
end

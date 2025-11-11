# frozen_string_literal: true

class DiscourseAi::Evals::PromptSingleTestRunner
  def initialize(llm)
    @llm = llm
  end

  # Run a single test with a prompt and message, and some model settings
  # @param prompt [String] the prompt to use
  # @param message [String] the message to use
  # @param followups [Array<Hash>] an array of followups (messages) to run after the initial prompt
  # @param output_thinking [Boolean] whether to output the thinking state of the model
  # @param stream [Boolean] whether to stream the output of the model
  # @param temperature [Float] the temperature to use when generating completions
  # @param tools [Array<Hash>] an array of tools to use when generating completions
  # @return [Hash] the prompt, message, and result of the test
  def run_single_test(prompt, message, followups, output_thinking, stream, temperature, tools)
    @c_prompt =
      DiscourseAi::Completions::Prompt.new(prompt, messages: [{ type: :user, content: message }])
    @c_prompt.tools = tools if tools
    generate_result(temperature, output_thinking, stream)

    if followups
      followups.each do |followup|
        generate_followup(followup, output_thinking, stream, temperature)
      end
    end

    { prompt:, message:, result: @result }
  end

  private

  def generate_followup(followup, output_thinking, stream, temperature)
    @c_prompt.push_model_response(@result)
    followup_message = set_followup_tool(followup)
    @c_prompt.push(**followup_message)
    begin
      generate_result(temperature, output_thinking, stream)
    rescue => e
      # should not happen but it helps debugging...
      puts e
      result = []
    end
  end

  def set_followup_tool(followup)
    @c_prompt.tools = followup[:tools] if followup[:tools]
    followup_message = followup[:message]
    %i[id name].each do |key|
      if followup_message[key].is_a?(Array)
        type, inner_key = followup_message[key]
        # this allows us to dynamically set the id or name of the tool call
        prev = @c_prompt.messages.reverse.find { |m| m[:type] == type.to_sym }
        followup_message[key] = prev[inner_key.to_sym] if prev
      end
    end
    followup_message
  end

  def generate_result(temperature, output_thinking, stream)
    @result =
      if stream
        stream_result = []
        @llm.generate(
          @c_prompt,
          user: Discourse.system_user,
          temperature:,
          output_thinking:,
        ) { |partial| stream_result << partial }
        stream_result
      else
        @llm.generate(@c_prompt, user: Discourse.system_user, temperature:, output_thinking:)
      end
  end
end

# frozen_string_literal: true

require "net/http"

class EndpointMock
  def initialize(model)
    @model = model
  end

  attr_reader :model

  def stub_simple_call(prompt)
    stub_response(prompt, simple_response)
  end

  def stub_tool_call(prompt)
    stub_response(prompt, tool_response, tool_call: true)
  end

  def stub_streamed_simple_call(prompt)
    with_chunk_array_support do
      stub_streamed_response(prompt, streamed_simple_deltas)
      yield
    end
  end

  def stub_streamed_tool_call(prompt)
    with_chunk_array_support do
      stub_streamed_response(prompt, tool_deltas, tool_call: true)
      yield
    end
  end

  def simple_response
    "1. Serenity\\n2. Laughter\\n3. Adventure"
  end

  def streamed_simple_deltas
    ["Mount", "ain", " ", "Tree ", "Frog"]
  end

  def tool_deltas
    ["<function", <<~REPLY.strip, <<~REPLY.strip, <<~REPLY.strip]
      _calls>
      <invoke>
      <tool_name>get_weather</tool_name>
      <parameters>
      <location>Sydney</location>
      <unit>c</unit>
      </para
      REPLY
      meters>
      </invoke>
      </funct
      REPLY
      ion_calls>
      REPLY
  end

  def tool_response
    tool_deltas.join
  end

  def invocation_response
    DiscourseAi::Completions::ToolCall.new(
      id: "tool_0",
      name: "get_weather",
      parameters: {
        location: "Sydney",
        unit: "c",
      },
    )
  end

  def tool_id
    "get_weather"
  end

  def tool
    {
      name: "get_weather",
      description: "Get the weather in a city",
      parameters: [
        { name: "location", type: "string", description: "the city name", required: true },
        {
          name: "unit",
          type: "string",
          description: "the unit of measurement celcius c or fahrenheit f",
          enum: %w[c f],
          required: true,
        },
      ],
    }
  end

  def with_chunk_array_support
    mock = mocked_http
    @original_net_http = ::FinalDestination.send(:remove_const, :HTTP)
    ::FinalDestination.send(:const_set, :HTTP, mock)

    yield
  ensure
    ::FinalDestination.send(:remove_const, :HTTP)
    ::FinalDestination.send(:const_set, :HTTP, @original_net_http)
  end

  def self.with_chunk_array_support(&blk)
    self.new(nil).with_chunk_array_support(&blk)
  end

  protected

  # Copied from https://github.com/bblimke/webmock/issues/629
  # Workaround for stubbing a streamed response
  def mocked_http
    Class.new(FinalDestination::HTTP) do
      def request(*)
        super do |response|
          response.instance_eval do
            def read_body(*, &block)
              if block_given?
                @body.each(&block)
              else
                super
              end
            end
          end

          yield response if block_given?

          response
        end
      end
    end
  end
end

class EndpointsCompliance
  def initialize(rspec, endpoint, dialect_klass, user)
    @rspec = rspec
    @endpoint = endpoint
    @dialect_klass = dialect_klass
    @user = user
  end

  delegate :expect, :eq, :be_present, to: :rspec

  def generic_prompt(tools: [])
    DiscourseAi::Completions::Prompt.new(
      "You write words",
      messages: [{ type: :user, content: "write 3 words" }],
      tools: tools,
    )
  end

  def dialect(prompt: generic_prompt)
    dialect_klass.new(prompt, endpoint.llm_model)
  end

  def regular_mode_simple_prompt(mock)
    mock.stub_simple_call(dialect.translate)

    completion_response = endpoint.perform_completion!(dialect, user)

    expect(completion_response).to eq(mock.simple_response)

    expect(AiApiAuditLog.count).to eq(1)
    log = AiApiAuditLog.first

    expect(log.provider_id).to eq(endpoint.provider_id)
    expect(log.user_id).to eq(user.id)
    expect(log.raw_request_payload).to be_present
    expect(log.raw_response_payload).to eq(mock.response(completion_response).to_json)
    expect(log.request_tokens).to eq(endpoint.prompt_size(dialect.translate))
    expect(log.response_tokens).to eq(endpoint.llm_model.tokenizer_class.size(completion_response))
  end

  def regular_mode_tools(mock)
    prompt = generic_prompt(tools: [mock.tool])
    a_dialect = dialect(prompt: prompt)
    mock.stub_tool_call(a_dialect.translate)

    completion_response = endpoint.perform_completion!(a_dialect, user)
    expect(completion_response).to eq(mock.invocation_response)
  end

  def streaming_mode_simple_prompt(mock)
    mock.stub_streamed_simple_call(dialect.translate) do
      completion_response = +""

      cancel_manager = DiscourseAi::Completions::CancelManager.new

      endpoint.perform_completion!(dialect, user, cancel_manager: cancel_manager) do |partial|
        completion_response << partial
        cancel_manager.cancel! if completion_response.split(" ").length == 2
      end

      expect(AiApiAuditLog.count).to eq(1)
      log = AiApiAuditLog.first

      expect(log.provider_id).to eq(endpoint.provider_id)
      expect(log.user_id).to eq(user.id)
      expect(log.raw_request_payload).to be_present
      expect(log.raw_response_payload).to be_present
      expect(log.request_tokens).to eq(endpoint.prompt_size(dialect.translate))

      expect(log.response_tokens).to eq(
        endpoint.llm_model.tokenizer_class.size(mock.streamed_simple_deltas[0...-1].join),
      )
    end
  end

  def streaming_mode_tools(mock)
    prompt = generic_prompt(tools: [mock.tool])
    a_dialect = dialect(prompt: prompt)

    cancel_manager = DiscourseAi::Completions::CancelManager.new

    mock.stub_streamed_tool_call(a_dialect.translate) do
      buffered_partial = []

      endpoint.perform_completion!(a_dialect, user, cancel_manager: cancel_manager) do |partial|
        buffered_partial << partial
        cancel_manager if partial.is_a?(DiscourseAi::Completions::ToolCall)
      end

      expect(buffered_partial).to eq([mock.invocation_response])
    end
  end

  attr_reader :rspec, :endpoint, :dialect_klass, :user
end

# frozen_string_literal: true

RSpec.describe AiApiAuditLogSerializer do
  before { enable_current_plugin }

  it "omits request attempts when the column is unavailable" do
    log = AiApiAuditLog.new(provider_id: AiApiAuditLog::Provider::OpenAI)
    original_has_attribute = log.method(:has_attribute?)
    log.define_singleton_method(:has_attribute?) do |attribute|
      attribute.to_sym == :request_attempts ? false : original_has_attribute.call(attribute)
    end

    serialized = described_class.new(log).as_json[:ai_api_audit_log]

    expect(serialized).not_to have_key(:request_attempts)
  end

  it "includes request attempts when the column is available" do
    log =
      AiApiAuditLog.new(
        provider_id: AiApiAuditLog::Provider::OpenAI,
        response_status: 200,
        duration_msecs: 22_300,
        time_to_first_token_msecs: 125,
        request_attempts: [
          { "status" => 429, "delay_ms" => 0 },
          { "status" => 200, "delay_ms" => 2000 },
        ],
      )

    serialized = described_class.new(log).as_json[:ai_api_audit_log]

    expect(serialized[:request_attempts]).to eq(
      [{ "status" => 429, "delay_ms" => 0 }, { "status" => 200, "delay_ms" => 2000 }],
    )
    expect(serialized[:response_status]).to eq(200)
    expect(serialized[:duration_msecs]).to eq(22_300)
    expect(serialized[:time_to_first_token_msecs]).to eq(125)
  end

  it "decodes supported streaming responses" do
    raw_response = <<~SSE
      data: {"choices":[{"delta":{"reasoning":"No"}}]}

      data: {"choices":[{"delta":{"reasoning":" funny stories"}}]}

      data: [DONE]

    SSE
    log = AiApiAuditLog.new(raw_response_payload: raw_response)

    serialized = described_class.new(log).as_json[:ai_api_audit_log]

    expect(serialized).to include(
      raw_response_payload: raw_response,
      decoded_response: {
        "thinking" => "No funny stories",
      },
    )
    expect(serialized).not_to have_key(:has_decoded_response)
  end

  it "returns nil when a response cannot be decoded" do
    raw_response = '{"choices":[{"message":{"content":"hello"}}]}'
    log = AiApiAuditLog.new(raw_response_payload: raw_response)

    serialized = described_class.new(log).as_json[:ai_api_audit_log]

    expect(serialized).to include(raw_response_payload: raw_response, decoded_response: nil)
  end

  it "safely serializes missing logs and response payloads" do
    expect(described_class.new(nil, root: false).as_json).to be_nil

    serialized =
      described_class.new(AiApiAuditLog.new(raw_response_payload: nil)).as_json[:ai_api_audit_log]
    expect(serialized).to include(decoded_response: nil)
  end

  it "includes a null time to first token for historical logs" do
    log = AiApiAuditLog.new(provider_id: AiApiAuditLog::Provider::OpenAI)

    serialized = described_class.new(log).as_json[:ai_api_audit_log]

    expect(serialized[:time_to_first_token_msecs]).to be_nil
  end
end

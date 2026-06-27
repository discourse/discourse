# frozen_string_literal: true

RSpec.describe AiApiAuditLogSerializer do
  before { enable_current_plugin }

  it "omits retry attempt statuses when the column is unavailable" do
    log = AiApiAuditLog.new(provider_id: AiApiAuditLog::Provider::OpenAI)
    original_has_attribute = log.method(:has_attribute?)
    log.define_singleton_method(:has_attribute?) do |attribute|
      attribute.to_sym == :retry_attempt_statuses ? false : original_has_attribute.call(attribute)
    end

    serialized = described_class.new(log).as_json[:ai_api_audit_log]

    expect(serialized).not_to have_key(:retry_attempt_statuses)
  end

  it "includes retry attempt statuses when the column is available" do
    log =
      AiApiAuditLog.new(
        provider_id: AiApiAuditLog::Provider::OpenAI,
        response_status: 200,
        retry_attempt_statuses: [429, 503],
      )

    serialized = described_class.new(log).as_json[:ai_api_audit_log]

    expect(serialized[:retry_attempt_statuses]).to eq([429, 503])
    expect(serialized[:response_status]).to eq(200)
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::SambaNova do
  fab!(:llm_model) { Fabricate(:samba_nova_model) }
  let(:llm) { llm_model.to_llm }

  before { enable_current_plugin }

  it "can stream completions" do
    body = <<~PARTS
    data: {"id": "4c5e4a44-e847-467d-b9cd-d2f6530678cd", "object": "chat.completion.chunk", "created": 1721336361, "model": "llama3-8b", "system_fingerprint": "fastcoe", "choices": [{"index": 0, "delta": {"content": "I am a bot"}, "logprobs": null, "finish_reason": null}]}

data: {"id": "4c5e4a44-e847-467d-b9cd-d2f6530678cd", "object": "chat.completion.chunk", "created": 1721336361, "model": "llama3-8b", "system_fingerprint": "fastcoe", "choices": [], "usage": {"is_last_response": true, "total_tokens": 62, "prompt_tokens": 21, "completion_tokens": 41, "time_to_first_token": 0.09152531623840332, "end_time": 1721336361.582011, "start_time": 1721336361.413994, "total_latency": 0.16801691055297852, "total_tokens_per_sec": 369.010475171488, "completion_tokens_per_sec": 244.02305616179046, "completion_tokens_after_first_per_sec": 522.9332759819093, "completion_tokens_after_first_per_sec_first_ten": 1016.0004844667837}}

data: [DONE]
    PARTS

    stub_request(:post, "https://api.sambanova.ai/v1/chat/completions").with(
      body:
        "{\"model\":\"samba-nova\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a helpful bot\"},{\"role\":\"user\",\"content\":\"who are you?\"}],\"stream\":true}",
      headers: {
        "Authorization" => "Bearer ABC",
        "Content-Type" => "application/json",
      },
    ).to_return(status: 200, body: body, headers: {})

    response = []
    llm.generate("who are you?", user: Discourse.system_user) { |partial| response << partial }

    expect(response).to eq(["I am a bot"])

    log = AiApiAuditLog.order(:id).last

    expect(log.request_tokens).to eq(21)
    expect(log.response_tokens).to eq(41)
  end

  it "can perform regular completions" do
    body = { choices: [message: { content: "I am a bot" }] }.to_json

    stub_request(:post, "https://api.sambanova.ai/v1/chat/completions").with(
      body:
        "{\"model\":\"samba-nova\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a helpful bot\"},{\"role\":\"user\",\"content\":\"who are you?\"}]}",
      headers: {
        "Authorization" => "Bearer ABC",
        "Content-Type" => "application/json",
      },
    ).to_return(status: 200, body: body, headers: {})

    response = llm.generate("who are you?", user: Discourse.system_user)

    expect(response).to eq("I am a bot")
  end
end

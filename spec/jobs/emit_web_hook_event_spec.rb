require 'rails_helper'

describe Jobs::EmitWebHookEvent do
  let(:post_hook) { Fabricate(:web_hook) }
  let(:inactive_hook) { Fabricate(:inactive_web_hook) }
  let(:post) { Fabricate(:post) }
  let(:user) { Fabricate(:user) }

  it 'raises an error when there is no web hook record' do
    expect do
      subject.execute(event_type: 'post', payload: {})
    end.to raise_error(Discourse::InvalidParameters)
  end

  it 'raises an error when there is no event type' do
    expect do
      subject.execute(web_hook_id: 1, payload: {})
    end.to raise_error(Discourse::InvalidParameters)
  end

  it 'raises an error when there is no payload' do
    expect do
      subject.execute(web_hook_id: 1, event_type: 'post')
    end.to raise_error(Discourse::InvalidParameters)
  end

  it 'does not raise an error for a ping event without payload' do
    stub_request(:post, "https://meta.discourse.org/webhook_listener")
      .to_return(body: 'OK', status: 200)

    subject.execute(
      web_hook_id: post_hook.id,
      event_type: described_class::PING_EVENT
    )
  end

  it "doesn't emit when the hook is inactive" do
    subject.execute(
      web_hook_id: inactive_hook.id,
      event_type: 'post',
      payload: { test: "some payload" }.to_json
    )
  end

  it 'emits normally with sufficient arguments' do
    stub_request(:post, "https://meta.discourse.org/webhook_listener")
      .with(body: "{\"post\":{\"test\":\"some payload\"}}")
      .to_return(body: 'OK', status: 200)

    subject.execute(
      web_hook_id: post_hook.id,
      event_type: 'post',
      payload: { test: "some payload" }.to_json
    )
  end

  context 'with category filters' do
    let(:category) { Fabricate(:category) }
    let(:topic) { Fabricate(:topic) }
    let(:topic_with_category) { Fabricate(:topic, category_id: category.id) }
    let(:topic_hook) { Fabricate(:topic_web_hook, categories: [category]) }

    it "doesn't emit when event is not related with defined categories" do
      subject.execute(
        web_hook_id: topic_hook.id,
        event_type: 'topic',
        category_id: topic.category.id,
        payload: { test: "some payload" }.to_json
      )
    end

    it 'emit when event is related with defined categories' do
      stub_request(:post, "https://meta.discourse.org/webhook_listener")
        .with(body: "{\"topic\":{\"test\":\"some payload\"}}")
        .to_return(body: 'OK', status: 200)

      subject.execute(
        web_hook_id: topic_hook.id,
        event_type: 'topic',
        category_id: topic_with_category.category.id,
        payload: { test: "some payload" }.to_json
      )
    end
  end

  describe '#web_hook_request' do
    it 'creates delivery event record' do
      stub_request(:post, "https://meta.discourse.org/webhook_listener")
        .to_return(body: 'OK', status: 200)

      WebHookEventType.all.pluck(:name).each do |name|
        web_hook_id = Fabricate("#{name}_web_hook").id

        expect do
          subject.execute(
            web_hook_id: web_hook_id,
            event_type: name,
            payload: { test: "some payload" }.to_json
          )
        end.to change(WebHookEvent, :count).by(1)
      end
    end

    it 'sets up proper request headers' do
      stub_request(:post, "https://meta.discourse.org/webhook_listener")
        .to_return(headers: { test: 'string' }, body: 'OK', status: 200)

      subject.execute(
        web_hook_id: post_hook.id,
        event_type: described_class::PING_EVENT,
        event_name: described_class::PING_EVENT,
        payload: { test: "this payload shouldn't appear" }.to_json
      )

      event = WebHookEvent.last
      headers = MultiJson.load(event.headers)
      expect(headers['Content-Length']).to eq(13)
      expect(headers['Host']).to eq("meta.discourse.org")
      expect(headers['X-Discourse-Event-Id']).to eq(event.id)
      expect(headers['X-Discourse-Event-Type']).to eq(described_class::PING_EVENT)
      expect(headers['X-Discourse-Event']).to eq(described_class::PING_EVENT)
      expect(headers['X-Discourse-Event-Signature']).to eq('sha256=162f107f6b5022353274eb1a7197885cfd35744d8d08e5bcea025d309386b7d6')
      expect(event.payload).to eq(MultiJson.dump(ping: 'OK'))
      expect(event.status).to eq(200)
      expect(MultiJson.load(event.response_headers)['Test']).to eq('string')
      expect(event.response_body).to eq('OK')
    end
  end
end

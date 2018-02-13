require 'rails_helper'

describe Jobs::EmitWebHookEvent do
  let(:post_hook) { Fabricate(:web_hook) }
  let(:inactive_hook) { Fabricate(:inactive_web_hook) }
  let(:post) { Fabricate(:post) }
  let(:user) { Fabricate(:user) }

  it 'raises an error when there is no web hook record' do
    expect { subject.execute(event_type: 'post') }.to raise_error(Discourse::InvalidParameters)
  end

  it 'raises an error when there is no event type' do
    expect { subject.execute(web_hook_id: 1) }.to raise_error(Discourse::InvalidParameters)
  end

  it "doesn't emit when the hook is inactive" do
    Jobs::EmitWebHookEvent.any_instance.expects(:web_hook_request).never
    subject.execute(web_hook_id: inactive_hook.id, event_type: 'post', post_id: post.id)
  end

  it 'emits normally with sufficient arguments' do
    Jobs::EmitWebHookEvent.any_instance.expects(:web_hook_request).once
    subject.execute(web_hook_id: post_hook.id, event_type: 'post', post_id: post.id)
  end

  context 'with category filters' do
    let(:category) { Fabricate(:category) }
    let(:topic) { Fabricate(:topic) }
    let(:topic_with_category) { Fabricate(:topic, category_id: category.id) }
    let(:topic_hook) { Fabricate(:topic_web_hook, categories: [category]) }

    it "doesn't emit when event is not related with defined categories" do
      Jobs::EmitWebHookEvent.any_instance.expects(:web_hook_request).never

      subject.execute(web_hook_id: topic_hook.id,
                      event_type: 'topic',
                      topic_id: topic.id,
                      user_id: user.id,
                      category_id: topic.category.id)
    end

    it 'emit when event is related with defined categories' do
      Jobs::EmitWebHookEvent.any_instance.expects(:web_hook_request).once

      subject.execute(web_hook_id: topic_hook.id,
                      event_type: 'topic',
                      topic_id: topic_with_category.id,
                      user_id: user.id,
                      category_id: topic_with_category.category.id)
    end
  end

  describe '.web_hook_request' do
    it 'creates delivery event record' do
      stub_request(:post, "https://meta.discourse.org/webhook_listener")
        .to_return(body: 'OK', status: 200)

      expect do
        subject.execute(web_hook_id: post_hook.id, event_type: 'post', post_id: post.id)
      end.to change(WebHookEvent, :count).by(1)
    end

    it 'skips silently on missing post' do
      expect do
        subject.execute(web_hook_id: post_hook.id, event_type: 'post', post_id: (Post.maximum(:id).to_i + 1))
      end.not_to raise_error
    end

    it 'should not skip trashed post' do
      stub_request(:post, "https://meta.discourse.org/webhook_listener")
        .to_return(body: 'OK', status: 200)

      expect do
        post.trash!
        subject.execute(web_hook_id: post_hook.id, event_type: 'post', post_id: post.id)
      end.to change(WebHookEvent, :count).by(1)
    end

    it 'sets up proper request headers' do
      stub_request(:post, "https://meta.discourse.org/webhook_listener")
        .to_return(headers: { test: 'string' }, body: 'OK', status: 200)

      subject.execute(web_hook_id: post_hook.id, event_type: 'ping', event_name: 'ping')
      event = WebHookEvent.last
      headers = MultiJson.load(event.headers)
      expect(headers['Content-Length']).to eq(13)
      expect(headers['Host']).to eq("meta.discourse.org")
      expect(headers['X-Discourse-Event-Id']).to eq(event.id)
      expect(headers['X-Discourse-Event-Type']).to eq('ping')
      expect(headers['X-Discourse-Event']).to eq('ping')
      expect(headers['X-Discourse-Event-Signature']).to eq('sha256=162f107f6b5022353274eb1a7197885cfd35744d8d08e5bcea025d309386b7d6')
      expect(event.payload).to eq(MultiJson.dump(ping: 'OK'))
      expect(event.status).to eq(200)
      expect(MultiJson.load(event.response_headers)['Test']).to eq('string')
      expect(event.response_body).to eq('OK')
    end
  end
end

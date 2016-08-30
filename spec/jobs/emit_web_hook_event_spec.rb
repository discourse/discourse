require 'rails_helper'

describe Jobs::EmitWebHookEvent do
  let(:post_hook) { Fabricate(:web_hook) }
  let(:inactive_hook) { Fabricate(:inactive_web_hook) }
  let(:post) { Fabricate(:post) }
  let(:user) { Fabricate(:user) }

  it 'raises an error when there is no web hook record' do
    expect { subject.execute(event_type: 'post') }.to raise_error(Discourse::InvalidParameters)
  end

  it 'raises an error when there is no event name' do
    expect { subject.execute(web_hook_id: 1) }.to raise_error(Discourse::InvalidParameters)
  end

  it 'raises an error when event name is invalid' do
    expect { subject.execute(web_hook_id: post_hook.id, event_type: 'post_random') }.to raise_error(Discourse::InvalidParameters)
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
    before(:all) { Excon.defaults[:mock] = true }
    after(:all) { Excon.defaults[:mock] = false }
    after(:each) { Excon.stubs.clear }

    it 'creates delivery event record' do
      Excon.stub({ url: "https://meta.discourse.org/webhook_listener" },
                 { body: 'OK', status: 200 })

      expect do
        subject.execute(web_hook_id: post_hook.id, event_type: 'post', post_id: post.id)
      end.to change(WebHookEvent, :count).by(1)
    end
  end
end

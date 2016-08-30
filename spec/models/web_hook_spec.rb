require 'rails_helper'

describe WebHook do
  it { is_expected.to validate_presence_of :payload_url }
  it { is_expected.to validate_presence_of :content_type }
  it { is_expected.to validate_presence_of :last_delivery_status }
  it { is_expected.to validate_presence_of :web_hook_event_types }

  describe '#content_types' do
    before { @content_types = WebHook.content_types }

    it "'json' (application/json) should be at 1st position" do
      expect(@content_types['application/json']).to eq 1
    end

    it "'url_encoded' (application/x-www-form-urlencoded) should be at 2st position" do
      expect(@content_types['application/x-www-form-urlencoded']).to eq 2
    end
  end

  describe '#last_delivery_statuses' do
    before { @last_delivery_statuses = WebHook.last_delivery_statuses }

    it "inactive should be at 1st position" do
      expect(@last_delivery_statuses[:inactive]).to eq 1
    end

    it "failed should be at 2st position" do
      expect(@last_delivery_statuses[:failed]).to eq 2
    end

    it "successful should be at 3st position" do
      expect(@last_delivery_statuses[:successful]).to eq 3
    end
  end

  context 'web hooks' do
    let!(:post_hook) { Fabricate(:web_hook) }
    let!(:topic_hook) { Fabricate(:topic_web_hook) }

    describe '#find_by_type' do
      it 'find relevant hooks' do
        expect(WebHook.find_by_type(:post)).to eq([post_hook])
        expect(WebHook.find_by_type(:topic)).to eq([topic_hook])
      end

      it 'excludes inactive hooks' do
        post_hook.update_attributes!(active: false)

        expect(WebHook.find_by_type(:post)).to eq([])
      end
    end

    describe '#enqueue_hooks' do
      it 'enqueues hooks with id and name' do
        Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: post_hook.id, event_type: 'post')

        WebHook.enqueue_hooks(:post)
      end

      it 'accepts additional parameters' do
        Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: post_hook.id, post_id: 1, event_type: 'post')

        WebHook.enqueue_hooks(:post, post_id: 1)
      end
    end

    context 'includes wildcard hooks' do
      let!(:wildcard_hook) { Fabricate(:wildcard_web_hook) }

      describe '#find_by_type' do
        it 'can find wildcard hooks' do
          expect(WebHook.find_by_type(:wildcard)).to eq([wildcard_hook])
        end

        it 'can include wildcard hooks' do
          expect(WebHook.find_by_type(:post).sort_by(&:id)).to eq([post_hook, wildcard_hook])
          expect(WebHook.find_by_type(:topic).sort_by(&:id)).to eq([topic_hook, wildcard_hook])

        end
      end

      describe '#enqueue_hooks' do
        it 'enqueues hooks with ids' do
          Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: post_hook.id, event_type: 'post')
          Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: wildcard_hook.id, event_type: 'post')

          WebHook.enqueue_hooks(:post)
        end

        it 'accepts additional parameters' do
          Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: post_hook.id, post_id: 1, event_type: 'post')
          Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: wildcard_hook.id, post_id: 1, event_type: 'post')

          WebHook.enqueue_hooks(:post, post_id: 1)
        end
      end
    end
  end
end

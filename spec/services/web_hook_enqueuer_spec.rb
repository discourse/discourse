require 'rails_helper'

RSpec.describe WebHookEnqueuer do
  describe '#find_by_type' do
    let(:enqueuer) { WebHookEnqueuer.new }
    let!(:post_hook) { Fabricate(:web_hook, payload_url: " https://example.com ") }
    let!(:topic_hook) { Fabricate(:topic_web_hook) }

    it "returns unique hooks" do
      post_hook.web_hook_event_types << WebHookEventType.find_by(name: 'topic')
      post_hook.update!(wildcard_web_hook: true)

      expect(enqueuer.find_by_type(:post)).to eq([post_hook])
    end

    it 'find relevant hooks' do
      expect(enqueuer.find_by_type(:post)).to eq([post_hook])
      expect(enqueuer.find_by_type(:topic)).to eq([topic_hook])
    end

    it 'excludes inactive hooks' do
      post_hook.update!(active: false)

      expect(enqueuer.find_by_type(:post)).to eq([])
      expect(enqueuer.find_by_type(:topic)).to eq([topic_hook])
    end
  end
end

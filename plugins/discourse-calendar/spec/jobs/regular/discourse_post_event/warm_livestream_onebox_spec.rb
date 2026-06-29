# frozen_string_literal: true

describe Jobs::WarmLivestreamOnebox do
  let(:livestream_url) { "https://example.com/live" }

  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:event) { Fabricate(:event, post: post, livestream: true, location: livestream_url) }

  before { Jobs.run_later! }

  it "publishes a changed post after warming the onebox" do
    event
    Oneboxer.expects(:onebox).with(livestream_url).returns("<aside>cached</aside>")

    messages =
      MessageBus.track_publish("/topic/#{post.topic_id}") do
        described_class.new.execute(event_id: event.id, url: livestream_url)
      end

    expect(messages.first.data).to include(id: post.id, type: :revised)
  end

  it "does not publish when the event URL has changed" do
    stale_url = "https://example.com/old-live"
    event
    Oneboxer.expects(:onebox).with(stale_url).returns("<aside>cached</aside>")

    messages =
      MessageBus.track_publish("/topic/#{post.topic_id}") do
        described_class.new.execute(event_id: event.id, url: stale_url)
      end

    expect(messages).to be_empty
  end
end

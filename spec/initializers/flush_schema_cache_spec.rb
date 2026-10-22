# frozen_string_literal: true

RSpec.describe "Flushing the schema cache over MessageBus" do
  let(:channel) { "/schema_cache_flush" }
  let(:schema_cache) { ActiveRecord::Base.connection_pool.schema_cache }
  # No model maps to this table, so only clearing the whole pool cache drops it.
  let(:table) { "schema_migrations" }

  # Subscribers on a channel run in registration order on the subscriber
  # thread, so once this one has seen a message the initializer's has too.
  def publish_and_wait(db)
    delivered = Queue.new
    callback = MessageBus.subscribe(channel) { |message| delivered << message.data }

    MessageBus.publish(channel, db)
    Timeout.timeout(5) { delivered.pop }
  ensure
    MessageBus.unsubscribe(channel, &callback)
  end

  before { schema_cache.columns_hash(table) }

  it "clears the schema cache of the published database's pool" do
    publish_and_wait(RailsMultisite::ConnectionManagement.current_db)

    expect(schema_cache.columns_hash?(table)).to eq(false)
  end

  it "keeps this pool's schema cache when another database is published" do
    publish_and_wait("some_other_db")

    expect(schema_cache.columns_hash?(table)).to eq(true)
  end
end

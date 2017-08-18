require 'rails_helper'

describe DiscourseRedis do
  let(:slave_host) { 'testhost' }
  let(:slave_port) { 1234 }

  let(:config) do
    DiscourseRedis.config.dup.merge(slave_host: 'testhost', slave_port: 1234, connector: DiscourseRedis::Connector)
  end

  let(:fallback_handler) { DiscourseRedis::FallbackHandler.instance }

  describe 'redis commands' do
    let(:raw_redis) { Redis.new(DiscourseRedis.config) }

    before do
      raw_redis.flushall
    end

    after do
      raw_redis.flushall
    end

    describe 'when namespace is enabled' do
      let(:redis) { DiscourseRedis.new }

      it 'should append namespace to the keys' do
        redis.set('key', 1)

        expect(raw_redis.get('default:key')).to eq('1')
        expect(redis.keys).to eq(['key'])

        redis.del('key')

        expect(raw_redis.get('default:key')).to eq(nil)

        raw_redis.set('default:key1', '1')
        raw_redis.set('default:key2', '2')

        expect(redis.mget('key1', 'key2')).to eq(['1', '2'])
      end
    end

    describe 'when namespace is disabled' do
      let(:redis) { DiscourseRedis.new(nil, namespace: false) }

      it 'should not append any namespace to the keys' do
        redis.set('key', 1)

        expect(raw_redis.get('key')).to eq('1')
        expect(redis.keys).to eq(['key'])

        redis.del('key')

        expect(raw_redis.get('key')).to eq(nil)

        raw_redis.set('key1', '1')
        raw_redis.set('key2', '2')

        expect(redis.mget('key1', 'key2')).to eq(['1', '2'])
      end

      it 'should noop a readonly redis' do
        expect(Discourse.recently_readonly?).to eq(false)

        redis.without_namespace
          .expects(:set)
          .raises(Redis::CommandError.new("READONLY"))

        redis.set('key', 1)

        expect(Discourse.recently_readonly?).to eq(true)
      end
    end
  end

  context '.slave_host' do
    it 'should return the right config' do
      slave_config = DiscourseRedis.slave_config(config)
      expect(slave_config[:host]).to eq(slave_host)
      expect(slave_config[:port]).to eq(slave_port)
    end
  end

  context 'when redis connection is to a slave redis server' do
    it 'should check the status of the master server' do
      begin
        fallback_handler.master = false
        $redis.without_namespace.expects(:set).raises(Redis::CommandError.new("READONLY"))
        fallback_handler.expects(:verify_master).once
        $redis.set('test', '1')
      ensure
        fallback_handler.master = true
      end
    end
  end

  describe DiscourseRedis::Connector do
    let(:connector) { DiscourseRedis::Connector.new(config) }

    it 'should return the master config when master is up' do
      expect(connector.resolve).to eq(config)
    end

    it 'should return the slave config when master is down' do
      begin
        Redis::Client.any_instance.expects(:call).raises(Redis::CannotConnectError).once
        expect { connector.resolve }.to raise_error(Redis::CannotConnectError)

        config = connector.resolve

        expect(config[:host]).to eq(slave_host)
        expect(config[:port]).to eq(slave_port)
      ensure
        fallback_handler.master = true
      end
    end

    class BrokenRedis
      def initialize(error)
        @error = error
      end

      def call(*args)
        raise @error
      end

      def disconnect
      end
    end

    it "should return the slave config when master's hostname cannot be resolved" do
      begin
        error = RuntimeError.new('Name or service not known')

        expect { connector.resolve(BrokenRedis.new(error)) }.to raise_error(error)
        fallback_handler.instance_variable_get(:@timer_task).shutdown
        expect(fallback_handler.running?).to eq(false)

        config = connector.resolve

        expect(config[:host]).to eq(slave_host)
        expect(config[:port]).to eq(slave_port)
        expect(fallback_handler.running?).to eq(true)
      ensure
        fallback_handler.master = true
      end
    end

    it "should return the slave config when master is still loading data" do
      begin
        Redis::Client.any_instance.expects(:call).with([:info]).returns("someconfig:haha\r\nloading:1")
        config = connector.resolve

        expect(config[:host]).to eq(slave_host)
        expect(config[:port]).to eq(slave_port)
      ensure
        fallback_handler.master = true
      end
    end

    it "should raise the right error" do
      error = RuntimeError.new('test error')
      Redis::Client.any_instance.expects(:call).raises(error).twice
      2.times { expect { connector.resolve }.to raise_error(error) }
    end
  end

  describe DiscourseRedis::FallbackHandler do
    after do
      fallback_handler.master = true
      MessageBus.keepalive_interval = -1
    end

    describe '#initiate_fallback_to_master' do
      it 'should return the right value if the master server is still down' do
        fallback_handler.master = false
        Redis::Client.any_instance.expects(:call).with([:info]).returns("Some other stuff")

        expect(fallback_handler.initiate_fallback_to_master).to eq(false)
        expect(MessageBus.keepalive_interval).to eq(0)
      end

      it 'should fallback to the master server once it is up' do
        fallback_handler.master = false
        Redis::Client.any_instance.expects(:call).with([:info]).returns(DiscourseRedis::FallbackHandler::MASTER_LINK_STATUS)

        DiscourseRedis::FallbackHandler::CONNECTION_TYPES.each do |connection_type|
          Redis::Client.any_instance.expects(:call).with([:client, [:kill, 'type', connection_type]])
        end

        expect(fallback_handler.initiate_fallback_to_master).to eq(true)
        expect(fallback_handler.master).to eq(true)
        expect(Discourse.recently_readonly?).to eq(false)
        expect(MessageBus.keepalive_interval).to eq(-1)
      end
    end
  end
end

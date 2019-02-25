require 'rails_helper'

describe DiscourseRedis do
  let(:slave_host) { 'testhost' }
  let(:slave_port) { 1234 }

  let(:config) do
    DiscourseRedis.config.dup.merge(slave_host: 'testhost', slave_port: 1234, connector: DiscourseRedis::Connector)
  end

  let(:fallback_handler) { DiscourseRedis::FallbackHandler.instance }

  it "ignore_readonly returns nil from a pure exception" do
    result = DiscourseRedis.ignore_readonly { raise Redis::CommandError.new("READONLY") }
    expect(result).to eq(nil)
  end

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
        raw_redis.set('default:key', 1)
        raw_redis.set('test:key2', 1)

        expect(redis.keys).to include('key')
        expect(redis.keys).to_not include('key2')
        expect(redis.scan_each.to_a).to eq(['key'])

        redis.scan_each.each do |key|
          expect(key).to eq('key')
        end

        redis.del('key')

        expect(raw_redis.get('default:key')).to eq(nil)
        expect(redis.scan_each.to_a).to eq([])

        raw_redis.set('default:key1', '1')
        raw_redis.set('default:key2', '2')

        expect(redis.mget('key1', 'key2')).to eq(['1', '2'])
        expect(redis.scan_each.to_a).to contain_exactly('key1', 'key2')
      end
    end

    describe 'when namespace is disabled' do
      let(:redis) { DiscourseRedis.new(nil, namespace: false) }

      it 'should not append any namespace to the keys' do
        raw_redis.set('default:key', 1)
        raw_redis.set('test:key2', 1)

        expect(redis.keys).to include('default:key', 'test:key2')

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
        $redis.del('test')
      end
    end
  end

  describe DiscourseRedis::Connector do
    let(:connector) { DiscourseRedis::Connector.new(config) }

    after do
      fallback_handler.master = true
    end

    it 'should return the master config when master is up' do
      expect(connector.resolve).to eq(config)
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

    it 'should return the slave config when master is down' do
      error = Redis::CannotConnectError

      expect do
        connector.resolve(BrokenRedis.new(error))
      end.to raise_error(Redis::CannotConnectError)

      config = connector.resolve

      expect(config[:host]).to eq(slave_host)
      expect(config[:port]).to eq(slave_port)
    end

    it "should return the slave config when master's hostname cannot be resolved" do
      error = RuntimeError.new('Name or service not known')

      expect do
        connector.resolve(BrokenRedis.new(error))
      end.to raise_error(error)

      expect(fallback_handler.master).to eq(false)

      config = connector.resolve

      expect(config[:host]).to eq(slave_host)
      expect(config[:port]).to eq(slave_port)
      expect(fallback_handler.master).to eq(false)
    end

    it "should return the slave config when master is still loading data" do
      Redis::Client.any_instance
        .expects(:call)
        .with([:info, :persistence])
        .returns("
          someconfig:haha\r
          #{DiscourseRedis::FallbackHandler::MASTER_LOADING_STATUS}
        ")

      config = connector.resolve

      expect(config[:host]).to eq(slave_host)
      expect(config[:port]).to eq(slave_port)
    end

    it "should raise the right error" do
      error = RuntimeError.new('test')

      2.times do
        expect { connector.resolve(BrokenRedis.new(error)) }
          .to raise_error(error)
      end
    end
  end

  describe DiscourseRedis::FallbackHandler do
    before do
      @original_keepalive_interval = MessageBus.keepalive_interval
    end

    after do
      fallback_handler.master = true
      MessageBus.keepalive_interval = @original_keepalive_interval
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
        master_conn = mock('master')
        slave_conn = mock('slave')

        Redis::Client.expects(:new)
          .with(DiscourseRedis.config)
          .returns(master_conn)

        Redis::Client.expects(:new)
          .with(DiscourseRedis.slave_config)
          .returns(slave_conn)

        master_conn.expects(:call)
          .with([:info])
          .returns("
            #{DiscourseRedis::FallbackHandler::MASTER_ROLE_STATUS}\r\n
            #{DiscourseRedis::FallbackHandler::MASTER_LOADED_STATUS}
          ")

        DiscourseRedis::FallbackHandler::CONNECTION_TYPES.each do |connection_type|
          slave_conn.expects(:call).with(
            [:client, [:kill, 'type', connection_type]]
          )
        end

        master_conn.expects(:disconnect)
        slave_conn.expects(:disconnect)

        expect(fallback_handler.initiate_fallback_to_master).to eq(true)
        expect(fallback_handler.master).to eq(true)
        expect(Discourse.recently_readonly?).to eq(false)
        expect(MessageBus.keepalive_interval).to eq(-1)
      end
    end
  end
end

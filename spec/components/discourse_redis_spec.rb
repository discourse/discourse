# frozen_string_literal: true

require 'rails_helper'

describe DiscourseRedis do
  before do
    DiscourseRedis::FallbackHandlers.instance.instance_variable_set(:@fallback_handlers, {})
  end

  let(:slave_host) { 'testhost' }
  let(:slave_port) { 1234 }

  let(:config) do
    GlobalSetting.redis_config.dup.merge(slave_host: 'testhost', slave_port: 1234, connector: DiscourseRedis::Connector)
  end

  let(:slave_config) { DiscourseRedis.slave_config(config) }

  it "ignore_readonly returns nil from a pure exception" do
    result = DiscourseRedis.ignore_readonly { raise Redis::CommandError.new("READONLY") }
    expect(result).to eq(nil)
  end

  let!(:master_conn) { mock('master') }

  def self.use_fake_threads
    attr_reader :execution

    around(:each) do |example|
      scenario =
        Concurrency::Scenario.new do |execution|
          @execution = execution
          example.run
        end

      scenario.run(sleep_order: true, runs: 1)
    end

    after(:each) do
      # Doing this here, as opposed to after example.run, ensures that it
      # happens before the mocha expectations are checked.
      execution.wait_done
    end
  end

  def stop_after(time)
    execution.sleep(time)
    execution.stop_other_tasks
  end

  def expect_master_info(conf = config)
    conf = conf.dup
    conf.delete(:connector)

    Redis::Client.expects(:new)
      .with(conf)
      .returns(master_conn)

    master_conn.expects(:disconnect)
    master_conn
      .expects(:call)
      .with([:info])
  end

  def info_response(*values)
    values.map { |x| x.join(':') }.join("\r\n")
  end

  def expect_fallback(config = slave_config)
    slave_conn = mock('slave')

    config = config.dup
    config.delete(:connector)

    Redis::Client.expects(:new)
      .with(config)
      .returns(slave_conn)

    slave_conn.expects(:call).with([:client, [:kill, 'type', 'normal']])
    slave_conn.expects(:call).with([:client, [:kill, 'type', 'pubsub']])
    slave_conn.expects(:disconnect)
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

  describe DiscourseRedis::RedisStatus do
    let(:redis_status) { DiscourseRedis::RedisStatus.new(config, slave_config) }

    context "#master_alive?" do
      it "returns false when the master's hostname cannot be resolved" do
        expect_master_info
          .raises(RuntimeError.new('Name or service not known'))

        expect(redis_status.master_alive?).to eq(false)
      end

      it "raises an error if a runtime error is raised" do
        error = RuntimeError.new('a random runtime error')
        expect_master_info.raises(error)

        expect {
          redis_status.master_alive?
        }.to raise_error(error)
      end

      it "returns false if the master is unavailable" do
        expect_master_info.raises(Redis::ConnectionError.new)

        expect(redis_status.master_alive?).to eq(false)
      end

      it "returns false if the master is loading" do
        expect_master_info
          .returns(info_response(['loading', '1'], ['role', 'master']))

        expect(redis_status.master_alive?).to eq(false)
      end

      it "returns false if the master is a slave" do
        expect_master_info
          .returns(info_response(['loading', '0'], ['role', 'slave']))

        expect(redis_status.master_alive?).to eq(false)
      end

      it "returns true when the master isn't loading and the role is master" do
        expect_master_info
          .returns(info_response(['loading', '0'], ['role', 'master']))

        expect(redis_status.master_alive?).to eq(true)
      end
    end

    context "#fallback" do
      it "instructs redis to kill client connections" do
        expect_fallback

        redis_status.fallback
      end
    end
  end

  describe DiscourseRedis::Connector do
    let(:connector) { DiscourseRedis::Connector.new(config) }
    let(:fallback_handler) { mock('fallback_handler') }

    before do
      DiscourseRedis::FallbackHandlers.stubs(:handler_for).returns(fallback_handler)
    end

    it 'should return the master config when master is up' do
      fallback_handler.expects(:use_master?).returns(true)
      expect(connector.resolve).to eq(config)
    end

    it 'should return the slave config when master is down' do
      fallback_handler.expects(:use_master?).returns(false)
      expect(connector.resolve).to eq(slave_config)
    end
  end

  describe DiscourseRedis::FallbackHandler do
    use_fake_threads

    let!(:redis_status) { mock }
    let!(:fallback_handler) { DiscourseRedis::FallbackHandler.new("", redis_status, execution) }

    context "in the initial configuration" do
      it "tests that the master is alive and returns true if it is" do
        redis_status.expects(:master_alive?).returns(true)

        expect(fallback_handler.use_master?).to eq(true)
      end

      it "tests that the master is alive and returns false if it is not" do
        redis_status.expects(:master_alive?).returns(false)
        expect(fallback_handler.use_master?).to eq(false)

        stop_after(1)
      end

      it "tests that the master is alive and returns false if it raises an exception" do
        error = Exception.new
        redis_status.expects(:master_alive?).raises(error)

        Discourse.expects(:warn_exception)
          .with(error, message: "Error running master_alive?")

        expect(fallback_handler.use_master?).to eq(false)

        stop_after(1)
      end
    end

    context "after master_alive? has returned false" do
      before do
        redis_status.expects(:master_alive?).returns(false)
        expect(fallback_handler.use_master?).to eq(false)
      end

      it "responds with false to the next call to use_master? without consulting redis_status" do
        expect(fallback_handler.use_master?).to eq(false)

        stop_after(1)
      end

      it "checks that master is alive again after a timeout" do
        redis_status.expects(:master_alive?).returns(false)

        stop_after(6)
      end

      it "checks that master is alive again and checks again if an exception is raised" do
        error = Exception.new
        redis_status.expects(:master_alive?).raises(error)

        Discourse.expects(:warn_exception)
          .with(error, message: "Error running master_alive?")

        execution.sleep(6)

        redis_status.expects(:master_alive?).returns(true)
        redis_status.expects(:fallback)

        stop_after(5)
      end

      it "triggers a fallback after master_alive? returns true" do
        redis_status.expects(:master_alive?).returns(true)
        redis_status.expects(:fallback)

        stop_after(6)
      end

      context "after falling back" do
        before do
          redis_status.expects(:master_alive?).returns(true)
          redis_status.expects(:fallback)

          stop_after(6)
        end

        it "tests that the master is alive and returns true if it is" do
          redis_status.expects(:master_alive?).returns(true)

          expect(fallback_handler.use_master?).to eq(true)
        end

        it "tests that the master is alive and returns false if it is not" do
          redis_status.expects(:master_alive?).returns(false)
          expect(fallback_handler.use_master?).to eq(false)

          stop_after(1)
        end

        it "tests that the master is alive and returns false if it raises an exception" do
          error = Exception.new
          redis_status.expects(:master_alive?).raises(error)

          Discourse.expects(:warn_exception)
            .with(error, message: "Error running master_alive?")

          expect(fallback_handler.use_master?).to eq(false)

          stop_after(1)
        end

        it "doesn't do anything to redis_status for a really long time" do
          stop_after(1e9)
        end
      end
    end
  end

  context "when message bus and main are on the same host" do
    use_fake_threads

    before do
      # Since config is based on GlobalSetting, we need to fetch it before
      # stubbing
      conf = config

      GlobalSetting.stubs(:redis_config).returns(conf)
      GlobalSetting.stubs(:message_bus_redis_config).returns(conf)

      Concurrency::ThreadedExecution.stubs(:new).returns(execution)
    end

    context "when the redis master goes down" do
      it "sets the message bus keepalive interval to 0" do
        expect_master_info
          .raises(Redis::ConnectionError.new)

        MessageBus.expects(:keepalive_interval=).with(0)

        DiscourseRedis::Connector.new(config).resolve

        execution.stop_other_tasks
      end
    end

    context "when the redis master comes back up" do
      before do
        MessageBus.keepalive_interval = 60

        expect_master_info
          .raises(Redis::ConnectionError.new)

        DiscourseRedis::Connector.new(config).resolve

        expect_master_info
          .returns(info_response(['loading', '0'], ['role', 'master']))

        expect_fallback
      end

      it "sets the message bus keepalive interval to its original value" do
        MessageBus.expects(:keepalive_interval=).with(60)
      end

      it "calls clear_readonly! and request_refresh! on Discourse" do
        Discourse.expects(:clear_readonly!)
        Discourse.expects(:request_refresh!)
      end
    end
  end

  context "when message bus and main are on different hosts" do
    use_fake_threads

    before do
      # Since config is based on GlobalSetting, we need to fetch it before stubbing
      conf = config

      GlobalSetting.stubs(:redis_config).returns(conf)

      message_bus_config = conf.dup
      message_bus_config[:port] = message_bus_config[:port].to_i + 1
      message_bus_config[:slave_port] = message_bus_config[:slave_port].to_i + 1

      GlobalSetting.stubs(:message_bus_redis_config).returns(message_bus_config)

      Concurrency::ThreadedExecution.stubs(:new).returns(execution)
    end

    let(:message_bus_master_config) {
      GlobalSetting.message_bus_redis_config
    }

    context "when the message bus master goes down" do
      before do
        expect_master_info(message_bus_master_config)
          .raises(Redis::ConnectionError.new)
      end

      it "sets the message bus keepalive interval to 0" do
        MessageBus.expects(:keepalive_interval=).with(0)

        DiscourseRedis::Connector.new(message_bus_master_config).resolve

        execution.stop_other_tasks
      end

      it "does not call clear_readonly! or request_refresh! on Discourse" do
        Discourse.expects(:clear_readonly!).never
        Discourse.expects(:request_refresh!).never

        DiscourseRedis::Connector.new(message_bus_master_config).resolve

        execution.stop_other_tasks
      end
    end

    context "when the message bus master comes back up" do
      before do
        MessageBus.keepalive_interval = 60

        expect_master_info(message_bus_master_config)
          .raises(Redis::ConnectionError.new)

        DiscourseRedis::Connector.new(message_bus_master_config).resolve

        expect_master_info(message_bus_master_config)
          .returns(info_response(['loading', '0'], ['role', 'master']))

        expect_fallback(DiscourseRedis.slave_config(message_bus_master_config))
      end

      it "sets the message bus keepalive interval to its original value" do
        MessageBus.expects(:keepalive_interval=).with(60)
      end
    end

    context "when the main master goes down" do
      before do
        expect_master_info
          .raises(Redis::ConnectionError.new)
      end

      it "does not change the message bus keepalive interval" do
        MessageBus.expects(:keepalive_interval=).never

        DiscourseRedis::Connector.new(config).resolve

        execution.stop_other_tasks
      end
    end

    context "when the main master comes back up" do
      before do
        expect_master_info
          .raises(Redis::ConnectionError.new)

        DiscourseRedis::Connector.new(config).resolve

        expect_master_info
          .returns(info_response(['loading', '0'], ['role', 'master']))

        expect_fallback
      end

      it "does not change the message bus keepalive interval" do
        MessageBus.expects(:keepalive_interval=).never
      end

      it "calls clear_readonly! and request_refresh! on Discourse" do
        Discourse.expects(:clear_readonly!)
        Discourse.expects(:request_refresh!)
      end
    end
  end
end

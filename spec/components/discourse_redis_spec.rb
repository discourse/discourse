require 'rails_helper'

describe DiscourseRedis do
  let(:slave_host) { 'testhost' }
  let(:slave_port) { 1234 }

  let(:config) do
    DiscourseRedis.config.dup.merge({
      slave_host: 'testhost', slave_port: 1234, connector: DiscourseRedis::Connector
    })
  end

  let(:fallback_handler) { DiscourseRedis::FallbackHandler.instance }

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
        $redis.without_namespace.expects(:get).raises(Redis::CommandError.new("READONLY"))
        fallback_handler.expects(:verify_master).once
        $redis.get('test')
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

    it "should return the slave config when master's hostname cannot be resolved" do
      begin
        error = RuntimeError.new('Name or service not known')

        Redis::Client.any_instance.expects(:call).raises(error).once
        expect { connector.resolve }.to raise_error(error)
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
    end

    describe '#initiate_fallback_to_master' do
      it 'should return the right value if the master server is still down' do
        fallback_handler.master = false
        Redis::Client.any_instance.expects(:call).with([:info]).returns("Some other stuff")
        expect(fallback_handler.initiate_fallback_to_master).to eq(false)
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
      end
    end
  end
end

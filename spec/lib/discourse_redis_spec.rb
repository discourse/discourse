# frozen_string_literal: true

describe DiscourseRedis do
  it "ignore_readonly returns nil from a pure exception" do
    result = DiscourseRedis.ignore_readonly { raise Redis::CommandError.new("READONLY") }
    expect(result).to eq(nil)
  end

  describe 'redis commands' do
    let(:raw_redis) { Redis.new(DiscourseRedis.config) }

    before do
      raw_redis.flushdb
    end

    after do
      raw_redis.flushdb
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

    describe "#eval" do
      it "keys and arvg are passed correcty" do
        keys = ["key1", "key2"]
        argv = ["arg1", "arg2"]

        expect(Discourse.redis.eval(
          "return { KEYS, ARGV };",
          keys: keys,
          argv: argv,
        )).to eq([keys, argv])

        expect(Discourse.redis.eval(
          "return { KEYS, ARGV };",
          keys,
          argv: argv,
        )).to eq([keys, argv])

        expect(Discourse.redis.eval(
          "return { KEYS, ARGV };",
          keys,
          argv,
        )).to eq([keys, argv])
      end
    end

    describe "#evalsha" do
      it "keys and arvg are passed correcty" do
        keys = ["key1", "key2"]
        argv = ["arg1", "arg2"]

        script = "return { KEYS, ARGV };"
        Discourse.redis.script(:load, script)
        sha = Digest::SHA1.hexdigest(script)
        expect(Discourse.redis.evalsha(
          sha,
          keys: keys,
          argv: argv,
        )).to eq([keys, argv])

        expect(Discourse.redis.evalsha(
          sha,
          keys,
          argv: argv,
        )).to eq([keys, argv])

        expect(Discourse.redis.evalsha(
          sha,
          keys,
          argv,
        )).to eq([keys, argv])
      end
    end
  end

  describe DiscourseRedis::EvalHelper do
    it "works" do
      helper = DiscourseRedis::EvalHelper.new <<~LUA
        return 'hello world'
      LUA
      expect(helper.eval(Discourse.redis)).to eq('hello world')
    end

    it "works with arguments" do
      helper = DiscourseRedis::EvalHelper.new <<~LUA
        return ARGV[1]..ARGV[2]..KEYS[1]..KEYS[2]
      LUA
      expect(helper.eval(Discourse.redis, ['key1', 'key2'], ['arg1', 'arg2'])).to eq("arg1arg2key1key2")
    end

    it "works with arguments" do
      helper = DiscourseRedis::EvalHelper.new <<~LUA
        return ARGV[1]..ARGV[2]..KEYS[1]..KEYS[2]
      LUA
      expect(helper.eval(Discourse.redis, ['key1', 'key2'], ['arg1', 'arg2'])).to eq("arg1arg2key1key2")
    end

    it "uses evalsha correctly" do
      redis_proxy = Class.new do
        attr_reader :calls
        def method_missing(meth, *args, **kwargs, &block)
          @calls ||= []
          @calls.push(meth)
          Discourse.redis.public_send(meth, *args, **kwargs, &block)
        end
      end.new

      Discourse.redis.call("SCRIPT", "FLUSH", "SYNC")

      helper = DiscourseRedis::EvalHelper.new <<~LUA
        return 'hello world'
      LUA
      expect(helper.eval(redis_proxy)).to eq("hello world")
      expect(helper.eval(redis_proxy)).to eq("hello world")
      expect(helper.eval(redis_proxy)).to eq("hello world")

      expect(redis_proxy.calls).to eq([:evalsha, :eval, :evalsha, :evalsha])
    end
  end
end

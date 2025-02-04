# frozen_string_literal: true

RSpec.describe DiscourseRedis do
  it "ignore_readonly returns nil from a pure exception" do
    result = DiscourseRedis.ignore_readonly { raise Redis::CommandError.new("READONLY") }
    expect(result).to eq(nil)
  end

  describe "redis commands" do
    let(:raw_redis) { Redis.new(DiscourseRedis.config) }

    before { raw_redis.flushdb }

    after { raw_redis.flushdb }

    describe "pipelined / multi" do
      let(:redis) { DiscourseRedis.new }

      it "should support multi commands" do
        val =
          redis.multi do |transaction|
            transaction.set "foo", "bar"
            transaction.set "bar", "foo"
            transaction.get "bar"
          end

        expect(raw_redis.get("foo")).to eq(nil)
        expect(raw_redis.get("bar")).to eq(nil)
        expect(redis.get("foo")).to eq("bar")
        expect(redis.get("bar")).to eq("foo")

        expect(val).to eq(%w[OK OK foo])
      end

      it "should support pipelined commands" do
        set, incr = nil
        val =
          redis.pipelined do |pipeline|
            set = pipeline.set "foo", "baz"
            incr = pipeline.incr "baz"
          end

        expect(val).to eq(["OK", 1])

        expect(set.value).to eq("OK")
        expect(incr.value).to eq(1)

        expect(raw_redis.get("foo")).to eq(nil)
        expect(raw_redis.get("baz")).to eq(nil)

        expect(redis.get("foo")).to eq("baz")
        expect(redis.get("baz")).to eq("1")
      end

      it "should noop pipelined commands against a readonly redis" do
        redis.without_namespace.expects(:pipelined).raises(Redis::CommandError.new("READONLY"))

        set, incr = nil

        val =
          redis.pipelined do |pipeline|
            set = pipeline.set "foo", "baz"
            incr = pipeline.incr "baz"
          end

        expect(val).to eq(nil)
        expect(redis.get("foo")).to eq(nil)
        expect(redis.get("baz")).to eq(nil)
      end

      it "should noop multi commands against a readonly redis" do
        redis.without_namespace.expects(:multi).raises(Redis::CommandError.new("READONLY"))

        val =
          redis.multi do |transaction|
            transaction.set "foo", "bar"
            transaction.set "bar", "foo"
            transaction.get "bar"
          end

        expect(val).to eq(nil)
        expect(redis.get("foo")).to eq(nil)
        expect(redis.get("bar")).to eq(nil)
      end
    end

    describe "when namespace is enabled" do
      let(:redis) { DiscourseRedis.new }

      it "should append namespace to the keys" do
        raw_redis.set("default:key", 1)
        raw_redis.set("test:key2", 1)
        raw_redis.set("default:key3", 1)

        expect(redis.keys).to include("key")
        expect(redis.keys).to_not include("key2")
        expect(redis.scan_each.to_a).to contain_exactly("key", "key3")

        redis.del("key", "key3")

        expect(raw_redis.get("default:key")).to eq(nil)
        expect(raw_redis.get("default:key3")).to eq(nil)

        expect(redis.scan_each.to_a).to eq([])

        raw_redis.set("default:key1", "1")
        raw_redis.set("default:key2", "2")

        expect(redis.mget("key1", "key2")).to eq(%w[1 2])
        expect(redis.scan_each.to_a).to contain_exactly("key1", "key2")
      end
    end

    describe "#sadd?" do
      it "should send the right command with the right key prefix to redis" do
        redis = DiscourseRedis.new

        redis.without_namespace.expects(:sadd?).with("default:testset", "1", anything)

        redis.sadd?("testset", "1")
      end
    end

    describe "#srem?" do
      it "should send the right command with the right key prefix to redis" do
        redis = DiscourseRedis.new

        redis.without_namespace.expects(:srem?).with("default:testset", "1", anything)

        redis.srem?("testset", "1")
      end
    end

    describe "when namespace is disabled" do
      let(:redis) { DiscourseRedis.new(nil, namespace: false) }

      it "should not append any namespace to the keys" do
        raw_redis.set("default:key", 1)
        raw_redis.set("test:key2", 1)

        expect(redis.keys).to include("default:key", "test:key2")

        raw_redis.set("key1", "1")
        raw_redis.set("key2", "2")

        expect(redis.mget("key1", "key2")).to eq(%w[1 2])

        redis.del("key1", "key2")

        expect(redis.mget("key1", "key2")).to eq([nil, nil])
      end

      it "should noop a readonly redis" do
        expect(Discourse.recently_readonly?).to eq(false)

        redis.without_namespace.expects(:set).raises(Redis::CommandError.new("READONLY"))

        redis.set("key", 1)

        expect(Discourse.recently_readonly?).to eq(true)
      end
    end

    describe "#eval" do
      it "keys and argv are passed correctly" do
        keys = %w[key1 key2]
        argv = %w[arg1 arg2]

        expect(Discourse.redis.eval("return { KEYS, ARGV };", keys: keys, argv: argv)).to eq(
          [keys, argv],
        )

        expect(Discourse.redis.eval("return { KEYS, ARGV };", keys, argv: argv)).to eq([keys, argv])

        expect(Discourse.redis.eval("return { KEYS, ARGV };", keys, argv)).to eq([keys, argv])
      end
    end

    describe "#evalsha" do
      it "keys and argv are passed correctly" do
        keys = %w[key1 key2]
        argv = %w[arg1 arg2]

        script = "return { KEYS, ARGV };"
        Discourse.redis.script(:load, script)
        sha = Digest::SHA1.hexdigest(script)
        expect(Discourse.redis.evalsha(sha, keys: keys, argv: argv)).to eq([keys, argv])

        expect(Discourse.redis.evalsha(sha, keys, argv: argv)).to eq([keys, argv])

        expect(Discourse.redis.evalsha(sha, keys, argv)).to eq([keys, argv])
      end
    end
  end

  describe DiscourseRedis::EvalHelper do
    it "works" do
      helper = DiscourseRedis::EvalHelper.new <<~LUA
        return 'hello world'
      LUA
      expect(helper.eval(Discourse.redis)).to eq("hello world")
    end

    it "works with arguments" do
      helper = DiscourseRedis::EvalHelper.new <<~LUA
        return ARGV[1]..ARGV[2]..KEYS[1]..KEYS[2]
      LUA
      expect(helper.eval(Discourse.redis, %w[key1 key2], %w[arg1 arg2])).to eq("arg1arg2key1key2")
    end

    it "uses evalsha correctly" do
      redis_proxy =
        Class
          .new do
            attr_reader :calls
            def method_missing(meth, *args, **kwargs, &block)
              @calls ||= []
              @calls.push(meth)
              Discourse.redis.public_send(meth, *args, **kwargs, &block)
            end
          end
          .new

      Discourse.redis.call("SCRIPT", "FLUSH", "SYNC")

      helper = DiscourseRedis::EvalHelper.new <<~LUA
        return 'hello world'
      LUA
      expect(helper.eval(redis_proxy)).to eq("hello world")
      expect(helper.eval(redis_proxy)).to eq("hello world")
      expect(helper.eval(redis_proxy)).to eq("hello world")

      expect(redis_proxy.calls).to eq(%i[evalsha eval evalsha evalsha])
    end
  end

  describe ".new_redis_store" do
    let(:cache) { Cache.new(namespace: "foo") }
    let(:store) { DiscourseRedis.new_redis_store }

    before do
      cache.redis.del("key")
      store.delete("key")
    end

    it "can store stuff" do
      store.fetch("key") { "key in store" }

      r = store.read("key")

      expect(r).to eq("key in store")
    end

    it "doesn't collide with our Cache" do
      store.fetch("key") { "key in store" }

      cache.fetch("key") { "key in cache" }

      r = store.read("key")

      expect(r).to eq("key in store")
    end

    it "can be cleared without clearing our cache" do
      cache.clear
      store.clear

      store.fetch("key") { "key in store" }

      cache.fetch("key") { "key in cache" }

      store.clear

      expect(store.read("key")).to eq(nil)
      expect(cache.fetch("key")).to eq("key in cache")
    end
  end
end

# frozen_string_literal: true

require "tempfile"

class GlobalSetting
  def self.reset_secret_key_base!
    @safe_secret_key_base = nil
  end
end

RSpec.describe GlobalSetting do
  describe ".use_s3_assets?" do
    it "returns false by default" do
      expect(GlobalSetting.use_s3?).to eq(false)
    end

    it "returns true once set" do
      global_setting :s3_bucket, "test_bucket"
      global_setting :s3_region, "ap-australia"
      global_setting :s3_access_key_id, "123"
      global_setting :s3_secret_access_key, "123"

      expect(GlobalSetting.use_s3?).to eq(true)
    end
  end

  describe ".safe_secret_key_base" do
    it "sets redis token if it is somehow flushed after 30 seconds" do
      # we have to reset so we reset all times and test runs consistently
      GlobalSetting.reset_secret_key_base!

      freeze_time Time.now

      token = GlobalSetting.safe_secret_key_base
      Discourse.redis.without_namespace.del(GlobalSetting::REDIS_SECRET_KEY)
      freeze_time Time.now + 20

      GlobalSetting.safe_secret_key_base
      new_token = Discourse.redis.without_namespace.get(GlobalSetting::REDIS_SECRET_KEY)
      expect(new_token).to eq(nil)

      freeze_time Time.now + 11

      GlobalSetting.safe_secret_key_base

      new_token = Discourse.redis.without_namespace.get(GlobalSetting::REDIS_SECRET_KEY)
      expect(new_token).to eq(token)
    end

    context "when a secret key is not provided and redis is not used" do
      before do
        GlobalSetting.skip_redis = true
        GlobalSetting.stubs(:secret_key_base).returns("")
        # Fail tests if redis calls are made
        Discourse.stubs(:redis).returns(nil)
      end

      after do
        GlobalSetting.skip_redis = false
        Discourse.unstub(:redis)
      end

      it "generates a new random key in memory without redis" do
        GlobalSetting.reset_secret_key_base!
        token = GlobalSetting.safe_secret_key_base
        new_token = GlobalSetting.safe_secret_key_base
        expect(new_token).to eq(token)
      end
    end
  end

  describe ".add_default" do
    after do
      class << GlobalSetting
        remove_method :foo_bar_foo
      end
    end

    it "can correctly add defaults" do
      GlobalSetting.add_default "foo_bar_foo", 1
      expect(GlobalSetting.foo_bar_foo).to eq(1)

      GlobalSetting.add_default "cdn_url", "a"
      expect(GlobalSetting.foo_bar_foo).not_to eq("a")
    end
  end

  describe ".redis_config" do
    describe "when replica config is not present" do
      it "should not set any connector" do
        expect(GlobalSetting.redis_config[:connector]).to eq(nil)
      end
    end

    describe "when replica config is present" do
      before { GlobalSetting.reset_redis_config! }

      after { GlobalSetting.reset_redis_config! }

      it "should set the right connector" do
        GlobalSetting.expects(:redis_replica_port).returns(6379).at_least_once
        GlobalSetting.expects(:redis_replica_host).returns("0.0.0.0").at_least_once

        expect(GlobalSetting.redis_config[:connector]).to eq(RailsFailover::Redis::Connector)
      end
    end
  end
end

RSpec.describe GlobalSetting::EnvProvider do
  it "can detect keys from env" do
    ENV["DISCOURSE_BLA"] = "1"
    ENV["DISCOURSE_BLA_2"] = "2"
    expect(GlobalSetting::EnvProvider.new.keys).to include(:bla)
    expect(GlobalSetting::EnvProvider.new.keys).to include(:bla_2)
  end
end

RSpec.describe GlobalSetting::FileProvider do
  it "can parse a simple file" do
    f = Tempfile.new("foo")
    f.write("  # this is a comment\n")
    f.write("\n")
    f.write(" a = 1000  # this is a comment\n")
    f.write("b = \"10 # = 00\"  # this is a # comment\n")
    f.write("c = \'10 # = 00\' # this is a # comment\n")
    f.write("d =\n")
    f.write("#f = 1\n")
    f.write("a1 = 1\n")
    f.close

    provider = GlobalSetting::FileProvider.from(f.path)

    expect(provider.lookup(:a, "")).to eq 1000
    expect(provider.lookup(:b, "")).to eq "10 # = 00"
    expect(provider.lookup(:c, "")).to eq "10 # = 00"
    expect(provider.lookup(:d, "bob")).to eq nil
    expect(provider.lookup(:e, "bob")).to eq "bob"
    expect(provider.lookup(:f, "bob")).to eq "bob"
    expect(provider.lookup(:a1, "")).to eq 1

    expect(provider.keys.sort).to eq %i[a a1 b c d]

    f.unlink
  end

  it "uses ERB" do
    f = Tempfile.new("foo")
    f.write("a = <%= 500 %>  # this is a comment\n")
    f.close

    provider = GlobalSetting::FileProvider.from(f.path)

    expect(provider.lookup(:a, "")).to eq 500

    f.unlink
  end
end

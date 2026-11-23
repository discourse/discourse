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

  describe ".configure!" do
    it "raises when config/discourse.conf exists" do
      File.stubs(:exist?).with(GlobalSetting::LEGACY_CONFIG_PATH).returns(true)

      expect { GlobalSetting.configure! }.to raise_error(/discourse\.conf is not supported/)
    end
  end

  describe ".redis_config" do
    describe "when replica config is not present" do
      it "does not set any custom client nor replica config" do
        expect(GlobalSetting.redis_config[:client_implementation]).to be_nil
        expect(GlobalSetting.redis_config[:custom]).to be_nil
      end
    end

    describe "when replica config is present" do
      before do
        GlobalSetting.reset_redis_config!
        GlobalSetting.expects(:redis_replica_port).returns(6379).at_least_once
        GlobalSetting.expects(:redis_replica_host).returns("0.0.0.0").at_least_once
      end

      after { GlobalSetting.reset_redis_config! }

      it "sets the right config" do
        expect(GlobalSetting.redis_config).to include(
          client_implementation: RailsFailover::Redis::Client,
          custom: {
            replica_host: "0.0.0.0",
            replica_port: 6379,
          },
        )
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
  it "reads typed values from a YAML file" do
    file = Tempfile.new(%w[global_settings .yml])
    file.write(<<~YAML)
      # a comment
      int: 1000
      negative_int: -1
      bool: false
      string: "10 # = 00"
      blank:
    YAML
    file.close

    provider = GlobalSetting::FileProvider.new(file.path)

    expect(provider.keys).to contain_exactly(:int, :negative_int, :bool, :string, :blank)
    expect(provider.lookup(:int, nil)).to eq(1000)
    expect(provider.lookup(:negative_int, nil)).to eq(-1)
    expect(provider.lookup(:bool, true)).to eq(false)
    expect(provider.lookup(:string, nil)).to eq("10 # = 00")
    expect(provider.lookup(:blank, "default")).to be_nil
    expect(provider.lookup(:missing, "default")).to eq("default")
  ensure
    file&.unlink
  end

  describe ".load_plugins? and .plugins_to_load" do
    around do |example|
      original = ENV["LOAD_PLUGINS"]
      example.run
    ensure
      original.nil? ? ENV.delete("LOAD_PLUGINS") : ENV["LOAD_PLUGINS"] = original
    end

    it "treats `1` as load-all" do
      ENV["LOAD_PLUGINS"] = "1"
      expect(GlobalSetting.load_plugins?).to eq(true)
      expect(GlobalSetting.plugins_to_load).to be_nil
    end

    it "treats `0` as load-none" do
      ENV["LOAD_PLUGINS"] = "0"
      expect(GlobalSetting.load_plugins?).to eq(false)
      expect(GlobalSetting.plugins_to_load).to be_nil
    end

    it "parses a comma-separated list, stripping whitespace and empty entries" do
      ENV["LOAD_PLUGINS"] = "  chat , automation ,, "
      expect(GlobalSetting.load_plugins?).to eq(true)
      expect(GlobalSetting.plugins_to_load).to eq(%w[chat automation])
    end

    it "tolerates `plugins/foo` entries by taking the basename" do
      ENV["LOAD_PLUGINS"] = "plugins/chat,plugins/automation"
      expect(GlobalSetting.plugins_to_load).to eq(%w[chat automation])
    end

    it "raises when given a list outside of dev/test" do
      ENV["LOAD_PLUGINS"] = "chat,automation"
      allow(Rails.env).to receive(:local?).and_return(false)
      expect { GlobalSetting.load_plugins? }.to raise_error(RuntimeError, /only supported/)
      expect { GlobalSetting.plugins_to_load }.to raise_error(RuntimeError, /only supported/)
    end
  end
end

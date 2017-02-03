require 'rails_helper'
require 'tempfile'

describe GlobalSetting do
  describe '.redis_config' do
    describe 'when slave config is not present' do
      it "should not set any connector" do
        expect(GlobalSetting.redis_config[:connector]).to eq(nil)
      end
    end

    describe 'when slave config is present' do
      before do
        GlobalSetting.reset_redis_config!
      end

      after do
        GlobalSetting.reset_redis_config!
      end

      it "should set the right connector" do
        GlobalSetting.expects(:redis_slave_port).returns(6379).at_least_once
        GlobalSetting.expects(:redis_slave_host).returns('0.0.0.0').at_least_once

        expect(GlobalSetting.redis_config[:connector]).to eq(DiscourseRedis::Connector)
      end
    end
  end
end

describe GlobalSetting::EnvProvider do
  it "can detect keys from env" do
    ENV['DISCOURSE_BLA'] = '1'
    ENV['DISCOURSE_BLA_2'] = '2'
    expect(GlobalSetting::EnvProvider.new.keys).to include(:bla)
    expect(GlobalSetting::EnvProvider.new.keys).to include(:bla_2)
  end
end

describe GlobalSetting::FileProvider do
  it "can parse a simple file" do
    f = Tempfile.new('foo')
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

    expect(provider.lookup(:a,"")).to eq 1000
    expect(provider.lookup(:b,"")).to eq "10 # = 00"
    expect(provider.lookup(:c,"")).to eq "10 # = 00"
    expect(provider.lookup(:d,"bob")).to eq nil
    expect(provider.lookup(:e,"bob")).to eq "bob"
    expect(provider.lookup(:f,"bob")).to eq "bob"
    expect(provider.lookup(:a1,"")).to eq 1

    expect(provider.keys.sort).to eq [:a, :a1, :b, :c, :d]

    f.unlink
  end

  it "uses ERB" do
    f = Tempfile.new('foo')
    f.write("a = <%= 500 %>  # this is a comment\n")
    f.close

    provider = GlobalSetting::FileProvider.from(f.path)

    expect(provider.lookup(:a,"")).to eq 500

    f.unlink
  end
end

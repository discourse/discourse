require 'spec_helper'
require 'tempfile'

describe GlobalSetting::EnvProvider do
  it "can detect keys from env" do
    ENV['DISCOURSE_BLA'] = '1'
    GlobalSetting::EnvProvider.new.keys.should include(:bla)
  end
end
describe GlobalSetting::FileProvider do
  it "can parse a simple file" do
    f = Tempfile.new('foo')
    f.write("  # this is a comment\n")
    f.write("\n")
    f.write("a = 1000  # this is a comment\n")
    f.write("b = \"10 # = 00\"  # this is a # comment\n")
    f.write("c = \'10 # = 00\' # this is a # comment\n")
    f.write("d =\n")
    f.close

    provider = GlobalSetting::FileProvider.from(f.path)

    provider.lookup(:a,"").should == 1000
    provider.lookup(:b,"").should == "10 # = 00"
    provider.lookup(:c,"").should == "10 # = 00"
    provider.lookup(:d,"bob").should == nil
    provider.lookup(:e,"bob").should == "bob"

    provider.keys.sort.should == [:a, :b, :c, :d]

    f.unlink
  end

  it "uses ERB" do
    f = Tempfile.new('foo')
    f.write("a = <%= 500 %>  # this is a comment\n")
    f.close

    provider = GlobalSetting::FileProvider.from(f.path)

    provider.lookup(:a,"").should == 500

    f.unlink
  end

end

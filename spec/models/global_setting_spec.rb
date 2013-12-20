require 'spec_helper'
require 'tempfile'

describe GlobalSetting::FileProvider do
  it "can parse a simple file" do
    f = Tempfile.new('foo')
    f.write("  # this is a comment\n")
    f.write("\n")
    f.write("a = 1000  # this is a comment\n")
    f.write("b = \"10 # = 00\"  # this is a # comment\n")
    f.write("c = \'10 # = 00\' # this is a # comment\n")
    f.close

    provider = GlobalSetting::FileProvider.from(f.path)

    provider.lookup(:a,"").should == 1000
    provider.lookup(:b,"").should == "10 # = 00"
    provider.lookup(:c,"").should == "10 # = 00"

    f.unlink
  end
end

require 'spec_helper'

describe ApplicationHelper do

  describe "escape_unicode" do
    it "encodes tags" do
      helper.escape_unicode("<tag>").should == "\u003ctag>"
    end
    it "survives junk text" do
      helper.escape_unicode("hello \xc3\x28 world").should =~ /hello.*world/
    end
  end

end

require 'spec_helper'
require_dependency 'oneboxer'

describe Oneboxer do
  it "returns blank string for an invalid onebox" do
    Oneboxer.preview("http://boom.com").should == ""
    Oneboxer.onebox("http://boom.com").should == ""
  end
end


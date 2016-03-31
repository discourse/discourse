require 'rails_helper'
require_dependency 'oneboxer'

describe Oneboxer do
  it "returns blank string for an invalid onebox" do
    expect(Oneboxer.preview("http://boom.com")).to eq("")
    expect(Oneboxer.onebox("http://boom.com")).to eq("")
  end
end


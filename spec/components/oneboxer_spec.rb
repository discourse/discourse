require 'rails_helper'
require_dependency 'oneboxer'

describe Oneboxer do

  it "returns blank string for an invalid onebox" do
    stub_request(:get, "http://boom.com").to_return(body: "")
    stub_request(:head, "http://boom.com").to_return(body: "")

    expect(Oneboxer.preview("http://boom.com")).to eq("")
    expect(Oneboxer.onebox("http://boom.com")).to eq("")
  end

end

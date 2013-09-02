require "spec_helper"

describe Onebox::Engine::Revision3Onebox do
  let(:link) { "http://collegehumor.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("collegehumor.response"))
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end

# frozen_string_literal: true
RSpec.describe "poc_canary" do
  it "prints host" do
    puts "POC_DISCOURSE_CANARY exec-on #{`hostname`.strip} uid #{Process.uid}"
    expect(true).to eq(true)
  end
end
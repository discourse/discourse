# frozen_string_literal: true

RSpec.shared_examples "a database connection" do
  it "responds to #insert" do
    expect(subject).to respond_to(:insert).with(1..2).arguments
  end

  it "responds to #close" do
    expect(subject).to respond_to(:close).with(0).arguments
  end

  it "responds to #closed?" do
    expect(subject).to respond_to(:closed?).with(0).arguments
  end
end

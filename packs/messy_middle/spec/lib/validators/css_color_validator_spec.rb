# frozen_string_literal: true

RSpec.describe CssColorValidator do
  subject { described_class.new }

  it "validates hex colors" do
    expect(subject.valid_value?("#0")).to eq(false)
    expect(subject.valid_value?("#00")).to eq(false)
    expect(subject.valid_value?("#000")).to eq(true)
    expect(subject.valid_value?("#0000")).to eq(false)
    expect(subject.valid_value?("#00000")).to eq(false)
    expect(subject.valid_value?("#000000")).to eq(true)
  end

  it "validates css colors" do
    expect(subject.valid_value?("red")).to eq(true)
    expect(subject.valid_value?("green")).to eq(true)
    expect(subject.valid_value?("blue")).to eq(true)
    expect(subject.valid_value?("hello")).to eq(false)
  end
end

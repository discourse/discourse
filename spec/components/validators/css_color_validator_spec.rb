# frozen_string_literal: true

require 'rails_helper'

describe CssColorValidator do
  subject { described_class.new }

  it "validates hex colors" do
    expect(subject.valid_value?('#0')).to be_falsey
    expect(subject.valid_value?('#00')).to be_falsey
    expect(subject.valid_value?('#000')).to be_truthy
    expect(subject.valid_value?('#0000')).to be_falsey
    expect(subject.valid_value?('#00000')).to be_falsey
    expect(subject.valid_value?('#000000')).to be_truthy
  end

  it "validates css colors" do
    expect(subject.valid_value?('red')).to be_truthy
    expect(subject.valid_value?('green')).to be_truthy
    expect(subject.valid_value?('blue')).to be_truthy
    expect(subject.valid_value?('hello')).to be_falsey
  end
end

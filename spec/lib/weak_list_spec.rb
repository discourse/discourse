# frozen_string_literal: true

RSpec.describe WeakList do
  it "acts like a list" do
    original = 10.times.map { Object.new }

    l = WeakList.new

    original.each { |item| l << item }

    expect(l.to_a).to eq(original)
  end

  it "removes GCed items" do
    prefix = 5.times.map { Object.new }
    suffix = 5.times.map { Object.new }

    l = WeakList.new

    (prefix + [Object.new] + suffix).each { |item| l << item }

    GC.start

    expect(l.to_a).to eq(prefix + suffix)
  end
end

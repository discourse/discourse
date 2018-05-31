require 'rails_helper'
require_dependency 'method_profiler'

describe MethodProfiler do
  class Sneetch
    def beach
    end

    def recurse(count = 5)
      if count > 0
        recurse(count - 1)
      end
    end
  end

  it "can bypass recursion on demand" do
    MethodProfiler.patch(Sneetch, [:recurse], :recurse, no_recurse: true)

    MethodProfiler.start
    Sneetch.new.recurse
    result = MethodProfiler.stop

    expect(result[:recurse][:calls]).to eq(1)
  end

  it "can transfer data between threads" do
    MethodProfiler.patch(Sneetch, [:beach], :at_beach)

    MethodProfiler.start
    Sneetch.new.beach
    data = MethodProfiler.transfer
    result = nil
    Thread.new do
      MethodProfiler.start(data)
      Sneetch.new.beach
      result = MethodProfiler.stop
    end.join

    expect(result[:at_beach][:calls]).to eq(2)
  end
end

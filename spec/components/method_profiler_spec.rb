require 'rails_helper'
require_dependency 'method_profiler'

describe MethodProfiler do
  class Sneetch
    def beach
    end
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

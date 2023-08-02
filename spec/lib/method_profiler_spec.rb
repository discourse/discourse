# frozen_string_literal: true

RSpec.describe MethodProfiler do
  class Sneetch
    def beach
    end

    def recurse(count = 5)
      recurse(count - 1) if count > 0
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
    Thread
      .new do
        MethodProfiler.start(data)
        Sneetch.new.beach
        result = MethodProfiler.stop
      end
      .join

    expect(result[:at_beach][:calls]).to eq(2)
  end

  it "profiles GC stat information when `track_gc_stat_per_request` site setting has been enabled" do
    MethodProfiler.start
    GC.start(full_mark: false) # Minor GC
    result = MethodProfiler.stop

    expect(result[:gc]).not_to be_present

    SiteSetting.track_gc_stat_per_request = true

    MethodProfiler.start
    GC.start(full_mark: true) # Major GC
    GC.start(full_mark: false) # Minor GC
    result = MethodProfiler.stop

    expect(result[:gc]).to be_present
    expect(result[:gc][:time]).to be >= 0.0
    expect(result[:gc][:major_count]).to eq(1)
    expect(result[:gc][:minor_count]).to eq(1)
  end
end

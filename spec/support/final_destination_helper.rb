# frozen_string_literal: true

WebMock::HttpLibAdapterRegistry.instance.register(
  :final_destination,
  Class.new do
    OriginalHTTP = FinalDestination::HTTP unless const_defined?(:OriginalHTTP)

    def self.enable!
      FinalDestination.send(:remove_const, :HTTP)
      FinalDestination.send(:const_set, :HTTP, Net::HTTP)
    end

    def self.disable!
      FinalDestination.send(:remove_const, :HTTP)
      FinalDestination.send(:const_set, :HTTP, OriginalHTTP)
    end
  end,
)

module FinalDestination::TestHelper
  def self.stub_to_fail(&blk)
    WebMock::HttpLibAdapterRegistry.instance.http_lib_adapters[:final_destination].disable!
    FinalDestination::SSRFDetector.stubs(:lookup_ips).returns(["0.0.0.0"])
    yield
  ensure
    WebMock::HttpLibAdapterRegistry.instance.http_lib_adapters[:final_destination].enable!
    FinalDestination::SSRFDetector.unstub(:lookup_ips)
  end
end

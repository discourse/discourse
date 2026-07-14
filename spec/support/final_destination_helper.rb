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
    adapters = WebMock::HttpLibAdapterRegistry.instance.http_lib_adapters
    # Let real connections through so both the Net::HTTP and http.rb SSRF checks run.
    adapters[:final_destination].disable!
    adapters[:http_rb].disable!
    FinalDestination::SSRFDetector.stubs(:lookup_ips).returns(["0.0.0.0"])
    yield
  ensure
    adapters[:final_destination].enable!
    adapters[:http_rb].enable!
    FinalDestination::SSRFDetector.unstub(:lookup_ips)
  end
end

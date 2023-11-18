# frozen_string_literal: true

describe EmberCli do
  describe ".ember_version" do
    it "works" do
      expect(EmberCli.ember_version).to match(/\A\d+\.\d+/)
    end
  end

  describe "cache" do
    after { EmberCli.clear_cache! }

    def simulate_request_cache_clearance
      # this method is defined by ActiveSupport::CurrentAttributes
      # and is called before/after every web request
      EmberCli.reset
    end

    context "in development" do
      before { Rails.env.stubs(:development?).returns(true) }

      it "cache works, and is cleared before/after each web request" do
        EmberCli.cache[:foo] = "bar"
        expect(EmberCli.cache[:foo]).to eq("bar")

        simulate_request_cache_clearance

        expect(EmberCli.cache[:foo]).to eq(nil)
      end
    end

    context "in production" do
      before { Rails.env.stubs(:development?).returns(false) }

      it "cache works, and can be cleared" do
        EmberCli.cache[:foo] = "bar"
        expect(EmberCli.cache[:foo]).to eq("bar")

        simulate_request_cache_clearance

        # In production, persists across requests
        expect(EmberCli.cache[:foo]).to eq("bar")

        # But still can be manually cleared
        EmberCli.clear_cache!
        expect(EmberCli.cache[:foo]).to eq(nil)
      end
    end
  end
end

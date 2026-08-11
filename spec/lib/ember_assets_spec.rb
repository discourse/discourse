# frozen_string_literal: true

describe EmberAssets do
  describe "cache" do
    after { EmberAssets.clear_cache! }

    context "in development" do
      before { Rails.env.stubs(:development?).returns(true) }

      it "cache works, and is cleared before/after each web request" do
        EmberAssets.cache[:foo] = "bar"
        expect(EmberAssets.cache[:foo]).to eq("bar")

        EmberAssets.reset

        expect(EmberAssets.cache[:foo]).to eq(nil)
      end
    end

    context "in production" do
      before { Rails.env.stubs(:development?).returns(false) }

      it "cache works, and can be cleared" do
        EmberAssets.cache[:foo] = "bar"
        expect(EmberAssets.cache[:foo]).to eq("bar")

        EmberAssets.reset

        # In production, persists across requests
        expect(EmberAssets.cache[:foo]).to eq("bar")

        # But still can be manually cleared
        EmberAssets.clear_cache!
        expect(EmberAssets.cache[:foo]).to eq(nil)
      end
    end
  end
end

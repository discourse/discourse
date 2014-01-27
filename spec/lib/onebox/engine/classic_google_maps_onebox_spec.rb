require "spec_helper"

describe Onebox::Engine::ClassicGoogleMapsOnebox do
  describe 'long form url' do
    before do
      @link = "https://maps.google.ca/maps?q=Eiffel+Tower,+Avenue+Anatole+France,+Paris,+France&hl=en&sll=43.656878,-79.32085&sspn=0.932941,1.50238&oq=eiffel+&t=m&z=17&iwloc=A"
    end

    include_context "engines"
    it_behaves_like "an engine"

    describe "#to_html" do
      it "embeds the iframe to display the map" do
        expect(html).to include("iframe")
      end
    end
  end

  describe 'short form url' do
    let(:long_url) { "https://maps.google.ca/maps?q=Brooklyn+Bridge,+Brooklyn,+NY,+United+States&hl=en&sll=43.656878,-79.32085&sspn=0.932941,1.50238&oq=brooklyn+bridge&t=m&z=17&iwloc=A" }

    it "retrieves the long form url" do
      onebox = described_class.new("http://goo.gl/maps/XffUa")
      onebox.expects(:get_long_url).once.returns(long_url)
      expect(onebox.url).to eq(long_url)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Onebox::Engine::GoogleMapsOnebox do
  URLS = {
    short: {
      test: "https://goo.gl/maps/rEG3D",
      redirect: [302, :long],
      expect:
        "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=embed&dg=ntvb&ll=40.689249,-74.0445&spn=0.0062479,0.0109864",
    },
    long: {
      test:
        "https://www.google.de/maps/place/Statue+of+Liberty+National+Monument/@40.689249,-74.0445,17z/data=!3m1!4b1!4m2!3m1!1s0x89c25090129c363d:0x40c6a5770d25022b",
      redirect: [301, :canonical],
      expect:
        "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=embed&dg=ntvb&ll=40.689249,-74.0445&spn=0.0062479,0.0109864",
    },
    canonical: {
      test:
        "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=classic&dg=ntvb",
      expect:
        "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=embed&dg=ntvb&ll=40.689249,-74.0445&spn=0.0062479,0.0109864",
    },
    custom: {
      test: "https://www.google.com/maps/d/edit?mid=zPYyZFrHi1MU.kX85W_Y2y2_E",
      expect: "https://www.google.com/maps/d/embed?mid=zPYyZFrHi1MU.kX85W_Y2y2_E",
    },
    streetview: {
      test:
        "https://www.google.com/maps/@46.414384,10.013947,3a,75y,232.83h,99.08t/data=!3m5!1e1!3m3!1s9WgYUb5quXDjqqFd3DWI6A!2e0!3e5?hl=de",
      expect:
        "https://www.google.com/maps/embed?pb=!3m2!2sen!4v0!6m8!1m7!1s9WgYUb5quXDjqqFd3DWI6A!2m2!1d46.414384!2d10.013947!3f232.83!4f9.908!5f0.75",
      streetview: true,
    },
    unresolveable: {
      test:
        "https://www.google.com/maps/place/Den+Abattoir/@51.2285173,4.4336702,17.5z/data=!4m7!1m4!3m3!1s0x47c3f7a5ac48e237:0x63d716018f584a33!2zUGnDqXRyYWlu!3b1!3m1!1s0x0000000000000000:0xfbfac0c41c32471a",
      redirect: [
        302,
        "https://www.google.com/maps/place/Den+Abattoir/@51.2285173,4.4336702,17.5z/data=!4m7!1m4!3m3!1s0x47c3f7a5ac48e237:0x63d716018f584a33!2zUGnDqXRyYWlu!3b1!3m1!1s0x0000000000000000:0xfbfac0c41c32471a?dg=dbrw&newdg=1",
      ],
      expect:
        "https://maps.google.com/maps?ll=51.2285173,4.4336702&z=17&output=embed&dg=ntvb&q=Den+Abattoir&cid=18157036796216755994",
    },
    satellite: {
      test: "https://www.google.de/maps/@40.6894264,-74.0449146,758m/data=!3m1!1e3",
      redirect: [
        302,
        "https://www.google.de/maps/@40.6894264,-74.0449146,758m/data=!3m1!1e3?dg=dbrw&newdg=1",
      ],
      expect: "https://maps.google.com/maps?ll=40.6894264,-74.0449146&z=16&output=embed&dg=ntvb",
    },
  }.freeze

  # Register URL redirects
  # Prevent sleep from wasting our time when we test with strange redirects
  subject(:onebox) do
    described_class
      .send(:allocate)
      .tap do |obj|
        obj.stubs(:sleep)
        obj.send(:initialize, link)
      end
  end

  before do
    URLS.values.each do |t|
      status, location = *t[:redirect]
      location = URLS[location][:test] if location.is_a? Symbol

      stub_request(:head, t[:test]).to_return(status: status, headers: { location: location })
    end
  end

  let(:data) { onebox.send(:data).deep_symbolize_keys }
  let(:link) { |example| URLS[example.metadata[:urltype] || :short][:test] }

  include_context "an engine", urltype: :short

  URLS.each do |kind, t|
    it "processes #{kind} url correctly", urltype: kind do
      expect(onebox.url).to eq t[:expect]
      expect(onebox.streetview?).to t[:streetview] ? be_truthy : be_falsey
      expect(onebox.to_html).to include("<iframe")
      expect(onebox.placeholder_html).to include("placeholder-icon map")
    end
  end
end

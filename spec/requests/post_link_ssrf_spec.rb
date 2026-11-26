# frozen_string_literal: true

RSpec.describe "SSRF protection for post links" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:category)

  let(:resolved_ip) { "3fff::1" }
  let(:offered_addresses) { Queue.new }
  let(:connection_aborted) { Class.new(StandardError) }

  before do
    SiteSetting.enable_inline_onebox_on_all_domains = false
    Jobs.run_immediately!
    sign_in(user)

    WebMock.enable!(except: [:final_destination])

    # The attacker controls the DNS answer; everything downstream of it stays real.
    FinalDestination::SSRFDetector.stubs(:lookup_ips).returns([resolved_ip])

    # `Connector.encode` receives exactly the addresses the SSRF filter approved,
    # immediately before the HTTP client opens the connection. Abort there so no
    # real connection is attempted.
    addresses = offered_addresses
    aborted = connection_aborted
    FinalDestination::Connector
      .stubs(:encode)
      .with do |_host, ips|
        addresses << ips
        true
      end
      .raises(aborted)
  end

  after do
    WebMock.enable!
    FinalDestination::SSRFDetector.unstub(:lookup_ips)
    FinalDestination::Connector.unstub(:encode)
  end

  def create_post_linking_to(url)
    post "/posts.json",
         params: {
           raw: "here is a link #{url} for more context",
           title: "SSRF check #{SecureRandom.hex(4)}",
           category: category.id,
         }
    expect(response.status).to eq(200)
  end

  def addresses_offered_while_crawling(url)
    create_post_linking_to(url)
    offered_addresses.pop(timeout: 2) || []
  end

  context "when the linked host resolves into the '3fff::/20' documentation range" do
    let(:resolved_ip) { "3fff::1" }

    it "does not hand it to the outbound HTTP client" do
      expect(addresses_offered_while_crawling("http://internal.test/page")).to be_empty
      expect(TopicLink.where(url: "http://internal.test/page").pick(:title)).to be_nil
    end
  end

  context "when the linked host resolves into the '5f00::/16' SRv6 SID range" do
    let(:resolved_ip) { "5f00::1" }

    it "does not hand it to the outbound HTTP client" do
      expect(addresses_offered_while_crawling("http://internal.test/page")).to be_empty
      expect(TopicLink.where(url: "http://internal.test/page").pick(:title)).to be_nil
    end
  end

  context "when the linked host resolves into the '100:0:0:1::/64' dummy range" do
    let(:resolved_ip) { "100:0:0:1::1" }

    it "does not hand it to the outbound HTTP client" do
      expect(addresses_offered_while_crawling("http://internal.test/page")).to be_empty
      expect(TopicLink.where(url: "http://internal.test/page").pick(:title)).to be_nil
    end
  end

  context "when the linked host resolves to the already-denied documentation address 2001:db8::1" do
    let(:resolved_ip) { "2001:db8::1" }

    it "does not hand it to the outbound HTTP client" do
      expect(addresses_offered_while_crawling("http://internal.test/page")).to be_empty
      expect(TopicLink.where(url: "http://internal.test/page").pick(:title)).to be_nil
    end
  end

  context "when the linked host resolves to a globally reachable address" do
    let(:resolved_ip) { "2606:2800:220:1:248:1893:25c8:1946" }

    it "hands it to the outbound HTTP client" do
      expect(addresses_offered_while_crawling("http://example.test/page")).to eq([resolved_ip])
    end
  end
end

# frozen_string_literal: true

describe DiscourseAi::Utils::DnsSrv do
  let(:domain) { "example.com" }
  let(:weighted_dns_results) do
    [
      Resolv::DNS::Resource::IN::SRV.new(1, 1, 443, "service1.example.com"),
      Resolv::DNS::Resource::IN::SRV.new(2, 2, 443, "service2.example.com"),
      Resolv::DNS::Resource::IN::SRV.new(2, 2, 443, "service3.example.com"),
      Resolv::DNS::Resource::IN::SRV.new(3, 1, 443, "service4.example.com"),
      Resolv::DNS::Resource::IN::SRV.new(3, 1, 443, "service5.example.com"),
    ]
  end

  before { enable_current_plugin }

  context "when there are several servers with the same priority" do
    before do
      Resolv::DNS.any_instance.stubs(:getresources).returns(weighted_dns_results)

      Discourse.cache.delete("dns_srv_lookup:#{domain}")

      (1..5).each do |i|
        stub_request(:get, "https://service#{i}.example.com/health").to_return(status: 200)
      end
    end

    it "picks a server" do
      selected_server = DiscourseAi::Utils::DnsSrv.lookup(domain)

      expect(weighted_dns_results).to include(selected_server)
      expect(selected_server.port).to eq(443)
    end

    it "doesn't pick a server with lower priority" do
      selected_server = DiscourseAi::Utils::DnsSrv.lookup(domain)
      expect(weighted_dns_results.filter { |r| r.priority == 1 }).to include(selected_server)
    end
  end

  context "when the first server is not available" do
    before do
      Resolv::DNS.any_instance.stubs(:getresources).returns(weighted_dns_results)

      Discourse.cache.delete("dns_srv_lookup:#{domain}")

      stub_request(:get, "https://service1.example.com/health").to_raise(Faraday::SSLError)

      (2..5).each do |i|
        stub_request(:get, "https://service#{i}.example.com/health").to_return(status: 200)
      end
    end

    it "picks another server" do
      selected_server = DiscourseAi::Utils::DnsSrv.lookup(domain)

      expect(weighted_dns_results).to include(selected_server)
      expect(selected_server.port).to eq(443)
      expect(selected_server.target.to_s).to_not eq("service1.example.com")
    end
  end

  context "when the multiple servers are not available" do
    before do
      Resolv::DNS.any_instance.stubs(:getresources).returns(weighted_dns_results)

      Discourse.cache.delete("dns_srv_lookup:#{domain}")

      (1..3).each do |i|
        stub_request(:get, "https://service#{i}.example.com/health").to_raise(Faraday::SSLError)
      end

      (4..5).each do |i|
        stub_request(:get, "https://service#{i}.example.com/health").to_return(status: 200)
      end
    end

    it "picks another server" do
      selected_server = DiscourseAi::Utils::DnsSrv.lookup(domain)

      expect(weighted_dns_results).to include(selected_server)
      expect(selected_server.port).to eq(443)
      expect(selected_server.target.to_s).to_not eq("service1.example.com")
      expect(selected_server.target.to_s).to_not eq("service2.example.com")
      expect(selected_server.target.to_s).to_not eq("service3.example.com")
    end
  end
end

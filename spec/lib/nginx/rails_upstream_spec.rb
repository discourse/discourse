# frozen_string_literal: true

require_relative "../../nginx/support/rails_upstream"

RSpec.describe Nginx::Support::RailsUpstream do
  describe ".shared" do
    after do
      if described_class.instance_variable_defined?(:@shared)
        described_class.remove_instance_variable(:@shared)
      end
    end

    it "reuses one upstream per test process" do
      expect(described_class.shared).to equal(described_class.shared)
    end
  end

  describe "#start" do
    it "reuses the Capybara server" do
      server = instance_double(Capybara::Server, port: 30_001)
      allow(server).to receive(:boot).and_return(server)
      allow(Capybara::Server).to receive(:new).and_return(server)
      upstream = described_class.new

      expect(upstream.start.port).to eq(30_001)
      expect(upstream.start.port).to eq(30_001)
      expect(Capybara::Server).to have_received(:new).once
    end
  end
end

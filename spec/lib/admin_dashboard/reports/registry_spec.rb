# frozen_string_literal: true

RSpec.describe AdminDashboard::Reports::Registry do
  let(:fake_provider) do
    Class.new(AdminDashboard::Reports::SourceProvider) { def self.source_name = "fake_source" }
  end

  let(:plugin) { Plugin::Instance.new }

  after do
    DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
      entry[:value] == fake_provider
    end
  end

  describe ".provider_for" do
    it "returns nil for an unknown source name" do
      expect(described_class.provider_for("nonexistent_source")).to be_nil
    end

    context "with a plugin-registered provider" do
      before do
        DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin)
      end

      it "finds it by source_name" do
        expect(described_class.provider_for("fake_source")).to eq(fake_provider)
      end

      it "accepts symbol source names" do
        expect(described_class.provider_for(:fake_source)).to eq(fake_provider)
      end
    end

    it "ignores providers from disabled plugins" do
      DiscoursePluginRegistry.register_admin_dashboard_report_source(
        fake_provider,
        stub(enabled?: false),
      )

      expect(described_class.provider_for("fake_source")).to be_nil
    end
  end

  describe ".providers" do
    before { DiscoursePluginRegistry.register_admin_dashboard_report_source(fake_provider, plugin) }

    it "combines core providers and plugin-registered providers" do
      expect(described_class.providers).to include(fake_provider)
      described_class::CORE_PROVIDERS.each { |p| expect(described_class.providers).to include(p) }
    end
  end
end

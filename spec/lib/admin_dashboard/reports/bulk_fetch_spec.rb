# frozen_string_literal: true

RSpec.describe AdminDashboard::Reports::BulkFetch do
  fab!(:admin)
  let(:guardian) { admin.guardian }
  let(:plugin) { Plugin::Instance.new }
  let(:registered_providers) { [] }

  def register_provider(klass)
    registered_providers << klass
    DiscoursePluginRegistry.register_admin_dashboard_report_source(klass, plugin)
  end

  after do
    DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
      registered_providers.include?(entry[:value])
    end
    if thread_pool = described_class.instance_variable_get(:@thread_pool)
      thread_pool.shutdown
      thread_pool.wait_for_termination(timeout: 1)
      described_class.remove_instance_variable(:@thread_pool)
    end
  end

  describe ".call" do
    it "fetches data from a real registered provider end-to-end" do
      result =
        described_class.call(
          items: [{ source: "core_report", identifier: "signups" }],
          filters: {
          },
          guardian: guardian,
        )

      expect(result[:items].size).to eq(1)
      item = result[:items].first
      expect(item).to include(source: "core_report", identifier: "signups", error: false)
      expect(item[:data][:type]).to eq("signups")
    end

    it "calls each item's provider individually so multiple items of the same source still both resolve" do
      single_item_only_provider =
        Class.new(AdminDashboard::Reports::SourceProvider) do
          define_singleton_method(:source_name) { "single_item_only_source" }
          define_singleton_method(:fetch_many) do |identifiers, guardian:, filters: {}|
            if identifiers.size != 1
              raise "expected exactly one identifier, got #{identifiers.size}"
            end
            { identifiers.first => { value: identifiers.first } }
          end
        end
      register_provider(single_item_only_provider)

      result =
        described_class.call(
          items: [
            { source: "single_item_only_source", identifier: "a" },
            { source: "single_item_only_source", identifier: "b" },
          ],
          filters: {
          },
          guardian: guardian,
        )

      by_identifier = result[:items].index_by { |item| item[:identifier] }
      expect(by_identifier["a"]).to include(data: { value: "a" }, error: false)
      expect(by_identifier["b"]).to include(data: { value: "b" }, error: false)
    end

    it "returns no items for an empty items array" do
      expect(described_class.call(items: [], filters: {}, guardian: guardian)).to eq(items: [])
    end

    it "treats a payload carrying its own error key as failed, without discarding the payload" do
      soft_failing_provider =
        Class.new(AdminDashboard::Reports::SourceProvider) do
          define_singleton_method(:source_name) { "soft_failing_source" }
          define_singleton_method(:fetch_many) do |identifiers, guardian:, filters: {}|
            identifiers.each_with_object({}) do |identifier, hash|
              hash[identifier] = { error: "syntax error at or near \"selct\"", empty: true }
            end
          end
        end
      register_provider(soft_failing_provider)

      result =
        described_class.call(
          items: [{ source: "soft_failing_source", identifier: "broken_query" }],
          filters: {
          },
          guardian: guardian,
        )

      item = result[:items].first
      expect(item[:error]).to eq(true)
      expect(item[:data]).to eq(error: "syntax error at or near \"selct\"", empty: true)
    end
  end
end

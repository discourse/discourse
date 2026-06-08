# frozen_string_literal: true

RSpec.describe Discourse::PerformanceFormatter::Capture, type: :request do
  describe ".collect_requests" do
    before do
      MethodProfiler.ensure_discourse_instrumentation!
      MethodProfiler.itemize_enabled = true
    end

    after { MethodProfiler.itemize_enabled = false }

    it "captures a per-request group with itemized sql for a request" do
      groups = described_class.collect_requests { get "/categories.json" }

      expect(response.status).to eq(200)

      group = groups.find { |candidate| candidate[:path] == "/categories.json" }
      expect(group).to be_present
      expect(group[:method]).to eq("GET")
      expect(group[:status]).to eq(200)
      expect(group[:sql].map { |item| item[:sql] }).to be_present
    end
  end
end

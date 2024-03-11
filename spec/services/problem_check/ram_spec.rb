# frozen_string_literal: true

RSpec.describe ProblemCheck::Ram do
  subject(:check) { described_class.new }

  before { MemInfo.any_instance.stubs(mem_total: total_ram) }

  context "when total ram is 1 GB" do
    let(:total_ram) { 1_025_272 }

    it { expect(check.call).to be_empty }
  end

  context "when total ram cannot be determined" do
    let(:total_ram) { nil }

    it { expect(check.call).to be_empty }
  end

  context "when total ram is less than 1 GB" do
    let(:total_ram) { 512_636 }

    it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
  end
end

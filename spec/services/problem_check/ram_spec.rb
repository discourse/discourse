# frozen_string_literal: true

RSpec.describe ProblemCheck::Ram do
  subject(:check) { described_class.new }

  before { MemInfo.any_instance.stubs(mem_total: total_ram) }

  context "when total ram is 1 GB" do
    let(:total_ram) { 1_025_272 }

    it { expect(check).to be_chill_about_it }
  end

  context "when total ram cannot be determined" do
    let(:total_ram) { nil }

    it { expect(check).to be_chill_about_it }
  end

  context "when total ram is less than 1 GB" do
    let(:total_ram) { 512_636 }

    it do
      expect(check).to have_a_problem.with_priority("low").with_message(
        "Your server is running with less than 1 GB of total memory. At least 1 GB of memory is recommended.",
      )
    end
  end
end

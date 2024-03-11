# frozen_string_literal: true

RSpec.describe ProblemCheck::HostNames do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Discourse.stubs(current_hostname: hostname) }

    context "when a production host name is configured" do
      let(:hostname) { "something.com" }

      it { expect(check.call).to be_empty }
    end

    context "when host name is set to localhost" do
      let(:hostname) { "localhost" }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when host name is set to production.localhost" do
      let(:hostname) { "production.localhost" }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end
  end
end

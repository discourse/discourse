# frozen_string_literal: true

RSpec.describe ProblemCheck::RailsEnv do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Rails.stubs(env: ActiveSupport::StringInquirer.new(environment)) }

    context "when running in production environment" do
      let(:environment) { "production" }

      it { expect(check.call).to be_empty }
    end

    context "when running in development environment" do
      let(:environment) { "development" }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when running in test environment" do
      let(:environment) { "test" }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end
  end
end

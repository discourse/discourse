# frozen_string_literal: true

RSpec.describe ProblemCheck::RailsEnv do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Rails.stubs(env: ActiveSupport::StringInquirer.new(environment)) }

    context "when running in production environment" do
      let(:environment) { "production" }

      it { expect(check).to be_chill_about_it }
    end

    context "when running in development environment" do
      let(:environment) { "development" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your server is running in development mode.",
        )
      end
    end

    context "when running in test environment" do
      let(:environment) { "test" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your server is running in test mode.",
        )
      end
    end
  end
end

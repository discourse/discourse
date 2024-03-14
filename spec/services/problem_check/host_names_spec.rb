# frozen_string_literal: true

RSpec.describe ProblemCheck::HostNames do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Discourse.stubs(current_hostname: hostname) }

    context "when a production host name is configured" do
      let(:hostname) { "something.com" }

      it { expect(check).to be_chill_about_it }
    end

    context "when host name is set to localhost" do
      let(:hostname) { "localhost" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your config/database.yml file is using the default localhost hostname. Update it to use your site's hostname.",
        )
      end
    end

    context "when host name is set to production.localhost" do
      let(:hostname) { "production.localhost" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your config/database.yml file is using the default localhost hostname. Update it to use your site's hostname.",
        )
      end
    end
  end
end

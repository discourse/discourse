# frozen_string_literal: true

RSpec.describe ProblemCheck::Landlock do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      Rails.stubs(env: ActiveSupport::StringInquirer.new(environment))
      Discourse::SafeExec.stubs(landlock_supported?: supported)
    end

    context "when running in production" do
      let(:environment) { "production" }

      context "when Landlock is supported" do
        let(:supported) { true }

        it { expect(check).to be_chill_about_it }
      end

      context "when Landlock is not supported" do
        let(:supported) { false }

        it "reports unavailable Landlock support" do
          expect(check).to have_a_problem.with_priority("high").with_message(
            "Landlock sandboxing is unavailable in this hosting environment, so external commands run without filesystem and network isolation. This is an important security protection that should not be missing in production. Use a Linux kernel with Landlock support (5.13 or later) to restore it.",
          )
        end
      end
    end

    context "when not running in production" do
      let(:environment) { "development" }
      let(:supported) { false }

      it { expect(check).to be_chill_about_it }
    end
  end
end

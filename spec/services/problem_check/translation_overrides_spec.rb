# frozen_string_literal: true

RSpec.describe ProblemCheck::TranslationOverrides do
  subject(:check) { described_class.new }

  around { |example| allow_missing_translations(&example) }

  describe ".call" do
    before { Fabricate(:translation_override, status: status) }

    context "when there are outdated translation overrides" do
      let(:status) { "outdated" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Some of your translation overrides are out of date. Please check your <a href='/admin/customize/site_texts?outdated=true'>text customizations</a>.",
        )
      end
    end

    context "when there are translation overrides with invalid interpolation keys" do
      let(:status) { "invalid_interpolation_keys" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Some of your translation overrides are out of date. Please check your <a href='/admin/customize/site_texts?outdated=true'>text customizations</a>.",
        )
      end
    end

    context "when all translation overrides are fine" do
      let(:status) { "up_to_date" }

      it { expect(check).to be_chill_about_it }
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin onboarding banner locale keys" do
  # OnboardingStep#buttonLabel switches between `action` and `completed`, so a
  # step missing either one renders the raw key in the banner.
  let(:steps) do
    File
      .read("frontend/discourse/app/components/admin-onboarding/banner.gjs")
      .scan(/static name = "(\w+)"/)
      .flatten
  end

  let(:banner) do
    YAML.load_file("config/locales/client.en.yml").dig("en", "js", "admin_onboarding_banner")
  end

  it "finds the steps defined by the banner" do
    expect(steps).to include("select_theme")
  end

  it "defines title, description, action and completed for every step" do
    missing =
      steps.each_with_object({}) do |step, hash|
        absent = %w[title description action completed] - (banner[step]&.keys || [])
        hash[step] = absent if absent.present?
      end

    expect(missing).to eq({})
  end
end

# frozen_string_literal: true

RSpec.describe "Admin onboarding banner locale keys" do
  let(:banner) do
    YAML.load_file("config/locales/client.en.yml").dig("en", "js", "admin_onboarding_banner")
  end

  # OnboardingStep#buttonLabel switches between `action` and `completed`, so a
  # step missing either one renders the raw key in the banner.
  it "defines title, description, action and completed for every step" do
    missing =
      UserHistory::ADMIN_ONBOARDING_STEPS.each_with_object({}) do |step, hash|
        absent = %w[title description action completed] - (banner[step]&.keys || [])
        hash[step] = absent if absent.present?
      end

    expect(missing).to eq({})
  end
end

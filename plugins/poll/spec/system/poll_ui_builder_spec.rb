# frozen_string_literal: true

describe "Poll UI Builder" do
  it "loads when local-dates plugin is disabled" do
    SiteSetting.discourse_local_dates_enabled = false

    visit "/"

    errors =
      $playwright_logger.logs.select do |log|
        log[:level] == "error" &&
          log[:message].include?("/discourse-local-dates/lib/generate-current-date-markup")
      end

    expect(errors).to be_empty
  end
end

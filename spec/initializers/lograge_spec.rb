# frozen_string_literal: true

RSpec.describe "Lograge custom options", if: DiscourseLograge.enabled? do
  it "applies the configured log truncation to the encoded parameters" do
    limit = GlobalSetting.log_line_max_chars
    event =
      ActiveSupport::Notifications::Event.new(
        "process_action.action_controller",
        0,
        0,
        "",
        { params: { "q" => "a" * limit }, headers: {} },
      )

    options = Rails.configuration.lograge.custom_options.call(event)

    expect(options.fetch(:params)).to eq(
      "#{event.payload[:params].to_query.first(limit)}...(truncated)",
    )
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseLograge, if: DiscourseLograge.enabled? do
  def logged_params(params)
    event =
      ActiveSupport::Notifications::Event.new(
        "process_action.action_controller",
        0,
        0,
        "",
        { params: params },
      )
    Rails.configuration.lograge.custom_options.call(event).fetch(:params)
  end

  it "preserves encoded parameters up to 4096 bytes" do
    expect(logged_params({ "q" => "a b" })).to eq("q=a+b")
    expect(logged_params({ "q" => "a" * 4094 })).to eq("q=#{"a" * 4094}")
  end

  it "truncates the combined encoded parameters to 4096 bytes" do
    result = logged_params({ "a" => "x" * 2048, "b" => "y" * 2048 })

    expect(result).to eq("a=#{"x" * 2048}&b=#{"y" * 2040}...")
  end
end

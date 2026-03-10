# frozen_string_literal: true

RSpec.describe CategorySetting do
  it { is_expected.to belong_to(:category) }

  it do
    is_expected.to validate_numericality_of(:num_auto_bump_daily)
      .only_integer
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it do
    is_expected.to validate_numericality_of(:auto_bump_cooldown_days)
      .only_integer
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it do
    is_expected.to define_enum_for(:topic_approval_type).with_values(
      %w[none all except_groups only_groups],
    ).without_scopes
  end

  it do
    is_expected.to define_enum_for(:reply_approval_type).with_values(
      %w[none all except_groups only_groups],
    ).without_scopes
  end
end

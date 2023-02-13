# frozen_string_literal: true

RSpec.describe CategorySetting do
  it { is_expected.to belong_to(:category) }

  it do
    is_expected.to validate_numericality_of(:num_auto_bump_daily)
      .only_integer
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end
end

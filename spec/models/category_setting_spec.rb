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

  it "removes category_posting_review_groups when approval is disabled" do
    category =
      Fabricate(
        :category,
        category_setting_attributes: {
          require_topic_approval: true,
          require_reply_approval: true,
        },
      )
    expect(category.category_posting_review_groups.count).to eq(2)

    category.require_topic_approval = false
    category.save!

    expect(category.category_posting_review_groups.pluck(:post_type)).to eq(%w[reply])

    category.require_reply_approval = false
    category.save!

    expect(category.category_posting_review_groups.count).to eq(0)
  end
end

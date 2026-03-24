# frozen_string_literal: true

RSpec.describe CategoryPostingReviewGroup do
  fab!(:category)

  subject do
    described_class.new(
      category: category,
      group: Group[:everyone],
      post_type: :topic,
      permission: :required,
    )
  end

  it { is_expected.to validate_presence_of(:category) }
  it { is_expected.to validate_presence_of(:group) }

  it "rejects non-everyone groups" do
    record =
      described_class.new(
        category: category,
        group: Fabricate(:group),
        post_type: :topic,
        permission: :required,
      )

    expect(record).not_to be_valid
    expect(record.errors[:base]).to include(
      "Group-based approval permissions for specific groups are not supported yet",
    )
  end
end

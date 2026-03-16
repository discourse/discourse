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

  it "allows non-everyone groups with required permission" do
    record =
      described_class.new(
        category: category,
        group: Fabricate(:group),
        post_type: :topic,
        permission: :required,
      )

    expect(record).to be_valid
  end

  it "allows non-everyone groups with exempt permission" do
    record =
      described_class.new(
        category: category,
        group: Fabricate(:group),
        post_type: :reply,
        permission: :exempt,
      )

    expect(record).to be_valid
  end

  it "destroys posting review groups when the group is destroyed" do
    group = Fabricate(:group)
    described_class.create!(
      category: category,
      group: group,
      post_type: :topic,
      permission: :required,
    )

    expect { group.destroy! }.to change(described_class, :count).by(-1)
  end
end

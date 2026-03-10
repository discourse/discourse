# frozen_string_literal: true

RSpec.describe CategoryApprovalGroup do
  it { is_expected.to belong_to(:category) }
  it { is_expected.to belong_to(:group) }
  it { is_expected.to validate_presence_of(:category) }
  it { is_expected.to validate_presence_of(:group) }
  it { is_expected.to validate_presence_of(:approval_type) }
  it do
    is_expected.to define_enum_for(:approval_type).with_values(
      "topic" => "topic",
      "reply" => "reply",
    ).backed_by_column_of_type(:string)
  end
end

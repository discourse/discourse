# frozen_string_literal: true

RSpec.describe CategorySerializer::CategorySettingSerializer do
  fab!(:category)

  it "exposes topic_approval_type and reply_approval_type" do
    category.category_setting.update!(
      topic_approval_type: :all,
      reply_approval_type: :except_groups,
    )
    json = described_class.new(category.category_setting, root: false).as_json
    expect(json[:topic_approval_type]).to eq("all")
    expect(json[:reply_approval_type]).to eq("except_groups")
  end
end

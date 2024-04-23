# frozen_string_literal: true

RSpec.describe PostFlag, type: :model do
  it "has id lower than 1000 for system flags" do
    post_flag = Fabricate(:post_flag, system: true)
    expect(post_flag.system?).to be true
    expect(post_flag.id).to be < 1000
  end

  it "has id greater than 1000 for non-system flags" do
    post_flag = Fabricate(:post_flag)
    expect(post_flag.system?).to be false
    expect(post_flag.id).to be > 1000
  end

  before { PostFlag.reset_post_action_types! }

  it "updates post action types when created, modified or destroyed" do
    expect(PostActionType.flag_types.keys).to eq(
      %i[off_topic inappropriate notify_user notify_moderators spam illegal],
    )

    post_flag = Fabricate(:post_flag, name: "custom")
    expect(PostActionType.flag_types.keys).to eq(
      %i[off_topic inappropriate notify_user notify_moderators spam illegal custom],
    )

    post_flag.update!(name: "edited_custom")
    expect(PostActionType.flag_types.keys).to eq(
      %i[off_topic inappropriate notify_user notify_moderators spam illegal edited_custom],
    )

    post_flag.destroy!
    expect(PostActionType.flag_types.keys).to eq(
      %i[off_topic inappropriate notify_user notify_moderators spam illegal],
    )
  end
end

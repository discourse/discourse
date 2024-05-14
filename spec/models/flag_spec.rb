# frozen_string_literal: true

RSpec.describe Flag, type: :model do
  it "has id lower than 1000 for system flags" do
    flag = Fabricate(:flag, id: 1)
    expect(flag.system?).to be true
  end

  it "has id greater than 1000 for non-system flags" do
    flag = Fabricate(:flag)
    expect(flag.system?).to be false
    expect(flag.id).to be > 1000
  end

  before { Flag.reset_flag_settings! }

  it "updates post action types when created, modified or destroyed" do
    expect(PostActionType.flag_types.keys).to eq(
      %i[notify_user notify_moderators off_topic inappropriate spam illegal],
    )
    expect(ReviewableScore.types.keys).to eq(
      %i[notify_user notify_moderators off_topic inappropriate spam illegal needs_approval],
    )

    flag = Fabricate(:flag, name: "custom")
    expect(PostActionType.flag_types.keys).to eq(
      %i[notify_user notify_moderators off_topic inappropriate spam illegal custom],
    )
    expect(ReviewableScore.types.keys).to eq(
      %i[notify_user notify_moderators off_topic inappropriate spam illegal custom needs_approval],
    )

    flag.update!(name: "edited_custom")
    expect(PostActionType.flag_types.keys).to eq(
      %i[notify_user notify_moderators off_topic inappropriate spam illegal edited_custom],
    )
    expect(ReviewableScore.types.keys).to eq(
      %i[
        notify_user
        notify_moderators
        off_topic
        inappropriate
        spam
        illegal
        edited_custom
        needs_approval
      ],
    )

    flag.destroy!
    expect(PostActionType.flag_types.keys).to eq(
      %i[notify_user notify_moderators off_topic inappropriate spam illegal],
    )
    expect(ReviewableScore.types.keys).to eq(
      %i[notify_user notify_moderators off_topic inappropriate spam illegal needs_approval],
    )
  end
end

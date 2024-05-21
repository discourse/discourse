# frozen_string_literal: true

RSpec.describe Flag, type: :model do
  before { Flag.reset_flag_settings! }

  it "has id lower than 1000 for system flags" do
    flag = Fabricate(:flag, id: 1)
    expect(flag.system?).to be true
  end

  it "has id greater than 1000 for non-system flags" do
    flag = Fabricate(:flag)
    expect(flag.system?).to be false
    expect(flag.id).to be > 1000
  end

  it "has correct name key" do
    flag = Fabricate(:flag, name: "CuStOm Flag!!!")
    expect(flag.name_key).to eq("custom_flag")

    flag.update!(name: "It's Illegal")
    expect(flag.name_key).to eq("its_illegal")

    flag.update!(name: "THIS IS    SPaM!+)(*&^%$#@@@!)")
    expect(flag.name_key).to eq("this_is_spam")
  end

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

# frozen_string_literal: true

RSpec.describe Flag, type: :model do
  after(:each) { Flag.reset_flag_settings! }

  it "has id lower than 1000 for system flags" do
    flag = Fabricate(:flag, id: 1)
    expect(flag.system?).to be true
    flag.destroy!
  end

  it "has id greater than 1000 for non-system flags" do
    flag = Fabricate(:flag)
    expect(flag.system?).to be false
    expect(flag.id).to be > 1000
    flag.destroy!
  end

  it "has correct name key" do
    flag = Fabricate(:flag, name: "FlAg!!!")
    expect(flag.name_key).to eq("custom_flag")

    flag.update!(name: "It's Illegal")
    expect(flag.name_key).to eq("custom_its_illegal")

    flag.update!(name: "THIS IS    SPaM!+)(*&^%$#@@@!)")
    expect(flag.name_key).to eq("custom_this_is_spam")

    flag.destroy!
  end

  it "updates post action types when created, modified or destroyed" do
    expect(PostActionType.flag_types.keys).to eq(
      %i[notify_user off_topic inappropriate spam illegal notify_moderators],
    )
    expect(ReviewableScore.types.keys).to eq(
      %i[notify_user off_topic inappropriate spam illegal notify_moderators needs_approval],
    )

    flag = Fabricate(:flag, name: "flag")
    expect(PostActionType.flag_types.keys).to eq(
      %i[notify_user off_topic inappropriate spam illegal notify_moderators custom_flag],
    )
    expect(ReviewableScore.types.keys).to eq(
      %i[
        notify_user
        off_topic
        inappropriate
        spam
        illegal
        notify_moderators
        custom_flag
        needs_approval
      ],
    )

    flag.update!(name: "edited_flag")
    expect(PostActionType.flag_types.keys).to eq(
      %i[notify_user off_topic inappropriate spam illegal notify_moderators custom_edited_flag],
    )
    expect(ReviewableScore.types.keys).to eq(
      %i[
        notify_user
        off_topic
        inappropriate
        spam
        illegal
        notify_moderators
        custom_edited_flag
        needs_approval
      ],
    )

    flag.destroy!
    expect(PostActionType.flag_types.keys).to eq(
      %i[notify_user off_topic inappropriate spam illegal notify_moderators],
    )
    expect(ReviewableScore.types.keys).to eq(
      %i[notify_user off_topic inappropriate spam illegal notify_moderators needs_approval],
    )
  end

  describe ".used_flag_ids" do
    fab!(:used_by_post_action_flag) { Fabricate(:flag) }
    fab!(:used_by_reviewable_score_flag) { Fabricate(:flag) }
    fab!(:unused_flag) { Fabricate(:flag) }

    fab!(:post_action) { Fabricate(:post_action, post_action_type_id: used_by_post_action_flag.id) }

    fab!(:reviewable_score) do
      Fabricate(:reviewable_score, reviewable_score_type: used_by_reviewable_score_flag.id)
    end

    it "returns the ids of flags that are associated to a `PostAction` or `ReviewableScore`" do
      expect(
        Flag.used_flag_ids(
          [used_by_post_action_flag.id, used_by_reviewable_score_flag.id, unused_flag.id],
        ),
      ).to contain_exactly(used_by_post_action_flag.id, used_by_reviewable_score_flag.id)
    end
  end
end

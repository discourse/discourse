# frozen_string_literal: true

require Rails.root.join("db/migrate/20260310072550_mark_category_approval_booleans_readonly.rb")
require Rails.root.join("db/migrate/20260310072759_create_category_approval_groups.rb")

RSpec.describe CreateCategoryApprovalGroups do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "backfills category_posting_review_groups from boolean approval columns" do
    topic_approval_category = Fabricate(:category)
    reply_approval_category = Fabricate(:category)
    both_approval_category = Fabricate(:category)
    no_approval_category = Fabricate(:category)

    CreateCategoryApprovalGroups.new.down
    MarkCategoryApprovalBooleansReadonly.new.down

    CategorySetting.where(
      category_id: [topic_approval_category.id, both_approval_category.id],
    ).update_all("require_topic_approval = true")

    CategorySetting.where(
      category_id: [reply_approval_category.id, both_approval_category.id],
    ).update_all("require_reply_approval = true")

    MarkCategoryApprovalBooleansReadonly.new.up
    CreateCategoryApprovalGroups.new.up

    everyone = Group::AUTO_GROUPS[:everyone]

    topic_groups = CategoryPostingReviewGroup.where(category_id: topic_approval_category.id)
    expect(topic_groups.count).to eq(1)
    expect(topic_groups.first).to have_attributes(
      post_type: "topic",
      permission: "required",
      group_id: everyone,
    )

    reply_groups = CategoryPostingReviewGroup.where(category_id: reply_approval_category.id)
    expect(reply_groups.count).to eq(1)
    expect(reply_groups.first).to have_attributes(
      post_type: "reply",
      permission: "required",
      group_id: everyone,
    )

    both_groups =
      CategoryPostingReviewGroup.where(category_id: both_approval_category.id).order(:post_type)
    expect(both_groups.count).to eq(2)
    expect(both_groups.first).to have_attributes(
      post_type: "topic",
      permission: "required",
      group_id: everyone,
    )
    expect(both_groups.second).to have_attributes(
      post_type: "reply",
      permission: "required",
      group_id: everyone,
    )

    expect(CategoryPostingReviewGroup.where(category_id: no_approval_category.id).count).to eq(0)
  end
end

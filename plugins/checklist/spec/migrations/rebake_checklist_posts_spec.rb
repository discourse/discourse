# frozen_string_literal: true

require Rails.root.join(
          "plugins/checklist/db/post_migrate/20260703130848_rebake_checklist_posts.rb",
        )

RSpec.describe RebakeChecklistPosts do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  fab!(:legacy_post, :post)
  fab!(:migrated_post, :post)
  fab!(:plain_post, :post)

  before do
    legacy_post.update_columns(
      cooked: '<p><span class="chcklst-box fa fa-square-o"></span> todo</p>',
      baked_version: Post::BAKED_VERSION,
    )
    migrated_post.update_columns(
      cooked: '<p><span class="chcklst-box fa fa-square-o" data-chk-off="0"></span> todo</p>',
      baked_version: Post::BAKED_VERSION,
    )
    plain_post.update_columns(cooked: "<p>no boxes here</p>", baked_version: Post::BAKED_VERSION)
  end

  it "nulls baked_version only for checklist posts that lack offsets" do
    described_class.new.up

    expect(legacy_post.reload.baked_version).to be_nil
    expect(migrated_post.reload.baked_version).to eq(Post::BAKED_VERSION)
    expect(plain_post.reload.baked_version).to eq(Post::BAKED_VERSION)
  end
end

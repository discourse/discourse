# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20260319054026_add_posting_review_modes_to_category_settings.rb",
        )

RSpec.describe AddPostingReviewModesToCategorySettings do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "backfills posting review modes from category_posting_review_groups" do
    topic_approval_category = Fabricate(:category)
    reply_approval_category = Fabricate(:category)
    both_approval_category = Fabricate(:category)
    no_approval_category = Fabricate(:category)

    ActiveRecord::Base.connection.remove_column :category_settings, :topic_posting_review_mode
    ActiveRecord::Base.connection.remove_column :category_settings, :reply_posting_review_mode

    unless ActiveRecord::Base.connection.column_exists?(
             :category_posting_review_groups,
             :permission,
           )
      ActiveRecord::Base.connection.add_column :category_posting_review_groups,
                                               :permission,
                                               :integer,
                                               default: 0,
                                               null: false
    end

    DB.exec(<<~SQL, category_id: topic_approval_category.id)
      INSERT INTO category_posting_review_groups (category_id, group_id, permission, post_type, created_at, updated_at)
      VALUES (:category_id, 0, 1, 0, now(), now())
    SQL

    DB.exec(<<~SQL, category_id: reply_approval_category.id)
      INSERT INTO category_posting_review_groups (category_id, group_id, permission, post_type, created_at, updated_at)
      VALUES (:category_id, 0, 1, 1, now(), now())
    SQL

    DB.exec(<<~SQL, category_id: both_approval_category.id)
      INSERT INTO category_posting_review_groups (category_id, group_id, permission, post_type, created_at, updated_at)
      VALUES (:category_id, 0, 1, 0, now(), now()),
             (:category_id, 0, 1, 1, now(), now())
    SQL

    described_class.new.up

    expect(
      DB.query_single(
        "SELECT topic_posting_review_mode, reply_posting_review_mode FROM category_settings WHERE category_id = ?",
        topic_approval_category.id,
      ),
    ).to eq([1, 0])

    expect(
      DB.query_single(
        "SELECT topic_posting_review_mode, reply_posting_review_mode FROM category_settings WHERE category_id = ?",
        reply_approval_category.id,
      ),
    ).to eq([0, 1])

    expect(
      DB.query_single(
        "SELECT topic_posting_review_mode, reply_posting_review_mode FROM category_settings WHERE category_id = ?",
        both_approval_category.id,
      ),
    ).to eq([1, 1])

    expect(
      DB.query_single(
        "SELECT topic_posting_review_mode, reply_posting_review_mode FROM category_settings WHERE category_id = ?",
        no_approval_category.id,
      ),
    ).to eq([0, 0])
  end
end

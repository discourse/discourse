# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20260925155026_trash_first_post_of_trashed_topics_in_deleted_categories.rb",
        )

RSpec.describe TrashFirstPostOfTrashedTopicsInDeletedCategories do
  fab!(:category, :category_with_definition)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "trashes the first post of trashed topics whose category no longer exists" do
    topic = category.topic
    Fabricate(:post, topic:)
    Fabricate(:whisper, topic:)
    Fabricate(:small_action, topic:)
    trashed_reply = Fabricate(:post, topic:, deleted_at: 1.day.ago)
    topic.trash!
    category.delete

    described_class.new.up

    topic = Topic.with_deleted.find(topic.id)
    expect(Post.only_deleted.where(topic_id: topic.id)).to contain_exactly(
      topic.first_post_with_deleted,
      trashed_reply,
    )
    expect(topic.posts_count).to eq(1)
  end

  it "leaves live orphans, trashed topics of existing categories and private messages untouched" do
    orphan = Fabricate(:category_with_definition)
    orphan.delete
    category.topic.trash!
    private_message = Fabricate(:private_message_post).topic
    private_message.trash!

    described_class.new.up

    expect(
      Post.only_deleted.where(topic_id: [orphan.topic_id, category.topic_id, private_message.id]),
    ).to be_empty
    expect(orphan.topic.reload.posts_count).to eq(1)
  end
end

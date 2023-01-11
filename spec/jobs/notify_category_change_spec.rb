# frozen_string_literal: true

RSpec.describe ::Jobs::NotifyCategoryChange do
  fab!(:user) { Fabricate(:user) }
  fab!(:regular_user) { Fabricate(:trust_level_4) }
  fab!(:post) { Fabricate(:post, user: regular_user) }
  fab!(:category) { Fabricate(:category, name: "test") }

  it "doesn't create notification for the editor who watches new tag" do
    CategoryUser.set_notification_level_for_category(
      user,
      CategoryUser.notification_levels[:watching_first_post],
      category.id,
    )
    post.topic.update!(category: category)
    post.update!(last_editor_id: user.id)

    expect { described_class.new.execute(post_id: post.id, notified_user_ids: []) }.not_to change {
      Notification.count
    }
  end
end

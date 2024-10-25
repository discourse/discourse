# frozen_string_literal: true

RSpec.describe ::Jobs::NotifyCategoryChange do
  fab!(:user)
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

  context "when mailing list mode is enabled" do
    before { SiteSetting.disable_mailing_list_mode = false }
    before do
      regular_user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 1)
    end
    before { Jobs.run_immediately! }

    it "notifies mailing list subscribers" do
      post.topic.update!(category: category)

      expected_args = { "post_id" => post.id, "current_site_id" => "default" }
      Jobs::NotifyMailingListSubscribers.any_instance.expects(:execute).with(expected_args).once
      described_class.new.execute(post_id: post.id, notified_user_ids: [])
    end
  end
end

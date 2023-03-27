# frozen_string_literal: true

RSpec.describe WebHookUserSerializer do
  let(:user) do
    user = Fabricate(:user)
    SingleSignOnRecord.create!(user_id: user.id, external_id: "12345", last_payload: "")
    user
  end

  fab!(:admin) { Fabricate(:admin) }

  let :serializer do
    WebHookUserSerializer.new(user, scope: Guardian.new(admin), root: false)
  end

  before do
    SiteSetting.navigation_menu = "legacy"
    SiteSetting.chat_enabled = false if defined?(::Chat)
  end

  it "should include relevant user info" do
    payload = serializer.as_json
    expect(payload[:email]).to eq(user.email)
    expect(payload[:external_id]).to eq("12345")
  end

  it "should only include the required keys" do
    expect(serializer.as_json.keys).to contain_exactly(
      :id,
      :username,
      :name,
      :avatar_template,
      :email,
      :secondary_emails,
      :last_posted_at,
      :last_seen_at,
      :created_at,
      :muted,
      :trust_level,
      :moderator,
      :admin,
      :title,
      :badge_count,
      :time_read,
      :recent_time_read,
      :primary_group_id,
      :primary_group_name,
      :flair_group_id,
      :flair_name,
      :flair_url,
      :flair_bg_color,
      :flair_color,
      :featured_topic,
      :staged,
      :pending_count,
      :profile_view_count,
      :second_factor_enabled,
      :can_upload_profile_header,
      :can_upload_user_card_background,
      :post_count,
      :locale,
      :muted_category_ids,
      :regular_category_ids,
      :watched_tags,
      :watching_first_post_tags,
      :tracked_tags,
      :muted_tags,
      :tracked_category_ids,
      :watched_category_ids,
      :watched_first_post_category_ids,
      :system_avatar_template,
      :muted_usernames,
      :ignored_usernames,
      :allowed_pm_usernames,
      :mailing_list_posts_per_day,
      :user_notification_schedule,
      :external_id,
      :featured_user_badge_ids,
      :invited_by,
      :groups,
      :user_option,
    )
  end
end

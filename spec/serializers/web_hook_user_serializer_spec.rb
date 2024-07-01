# frozen_string_literal: true

RSpec.describe WebHookUserSerializer do
  let(:user) do
    user = Fabricate(:user)
    SingleSignOnRecord.create!(user_id: user.id, external_id: "12345", last_payload: "")
    user
  end

  fab!(:admin)

  let :serializer do
    WebHookUserSerializer.new(user, scope: Guardian.new(admin), root: false)
  end

  it "should include relevant user info" do
    payload = serializer.as_json
    expect(payload[:email]).to eq(user.email)
    expect(payload[:external_id]).to eq("12345")
  end

  it "should only include the required keys" do
    expect(serializer.as_json.keys).to contain_exactly(
      :admin,
      :allowed_pm_usernames,
      :avatar_template,
      :badge_count,
      :can_ignore_users,
      :can_mute_users,
      :can_upload_profile_header,
      :can_upload_user_card_background,
      :created_at,
      :email,
      :external_id,
      :featured_topic,
      :featured_user_badge_ids,
      :flair_bg_color,
      :flair_color,
      :flair_group_id,
      :flair_name,
      :flair_url,
      :groups,
      :id,
      :ignored_usernames,
      :invited_by,
      :last_posted_at,
      :last_seen_at,
      :locale,
      :mailing_list_posts_per_day,
      :moderator,
      :muted_category_ids,
      :muted_tags,
      :muted_usernames,
      :muted,
      :name,
      :pending_count,
      :post_count,
      :primary_group_id,
      :primary_group_name,
      :profile_view_count,
      :recent_time_read,
      :regular_category_ids,
      :second_factor_enabled,
      :secondary_emails,
      :staged,
      :system_avatar_template,
      :time_read,
      :title,
      :tracked_category_ids,
      :tracked_tags,
      :trust_level,
      :user_notification_schedule,
      :user_option,
      :username,
      :watched_category_ids,
      :watched_first_post_category_ids,
      :watched_tags,
      :watching_first_post_tags,
    )
  end
end

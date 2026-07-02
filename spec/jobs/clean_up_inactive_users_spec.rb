# frozen_string_literal: true

RSpec.describe Jobs::CleanUpInactiveUsers do
  it "should clean up new users that have been inactive" do
    SiteSetting.clean_up_inactive_users_after_days = 0

    user =
      Fabricate(
        :user,
        created_at: 5.days.ago,
        last_seen_at: 5.days.ago,
        trust_level: TrustLevel.levels[:newuser],
      )

    Fabricate(:active_user)

    Fabricate(
      :post,
      user:
        Fabricate(
          :user,
          trust_level: TrustLevel.levels[:newuser],
          created_at: 5.days.ago,
          last_seen_at: 5.days.ago,
        ),
    ).user

    Fabricate(
      :user,
      trust_level: TrustLevel.levels[:newuser],
      created_at: 5.days.ago,
      last_seen_at: 2.days.ago,
    )

    Fabricate(:user, trust_level: TrustLevel.levels[:basic], created_at: 5.days.ago)

    expect { described_class.new.execute({}) }.to_not change { User.count }

    SiteSetting.clean_up_inactive_users_after_days = 4

    expect { described_class.new.execute({}) }.to change { User.count }.by(-1)

    expect(User.exists?(id: user.id)).to eq(false)
  end

  it "doesn't delete inactive admins" do
    SiteSetting.clean_up_inactive_users_after_days = 4
    admin =
      Fabricate(
        :admin,
        created_at: 5.days.ago,
        last_seen_at: 5.days.ago,
        trust_level: TrustLevel.levels[:newuser],
      )

    expect { described_class.new.execute({}) }.to_not change { User.count }
    expect(User.exists?(admin.id)).to eq(true)
  end

  it "doesn't delete inactive mods" do
    SiteSetting.clean_up_inactive_users_after_days = 4
    moderator =
      Fabricate(
        :moderator,
        created_at: 5.days.ago,
        last_seen_at: 5.days.ago,
        trust_level: TrustLevel.levels[:newuser],
      )

    expect { described_class.new.execute({}) }.to_not change { User.count }
    expect(User.exists?(moderator.id)).to eq(true)
  end

  it "should clean up a user that has a deleted post" do
    SiteSetting.clean_up_inactive_users_after_days = 1

    Fabricate(:active_user)

    Fabricate(
      :post,
      user:
        Fabricate(
          :user,
          trust_level: TrustLevel.levels[:newuser],
          created_at: 5.days.ago,
          last_seen_at: 2.days.ago,
        ),
      # ensuring that topic author is a different user as the topic is non-deleted
      topic: Fabricate(:topic, user: Fabricate(:user)),
      deleted_at: Time.now,
    ).user

    expect { described_class.new.execute({}) }.to change { User.count }.by(-1)
  end

  it "should clean up user that has a deleted topic" do
    SiteSetting.clean_up_inactive_users_after_days = 1

    Fabricate(:active_user)

    Fabricate(
      :topic,
      user:
        Fabricate(
          :user,
          trust_level: TrustLevel.levels[:newuser],
          created_at: 2.days.ago,
          last_seen_at: 2.days.ago,
        ),
      deleted_at: Time.now,
    ).user

    expect { described_class.new.execute({}) }.to change { User.count }.by(-1)
  end

  it "doesn't delete a user who has liked a post" do
    SiteSetting.clean_up_inactive_users_after_days = 4
    user =
      Fabricate(
        :user,
        created_at: 5.days.ago,
        last_seen_at: 5.days.ago,
        trust_level: TrustLevel.levels[:newuser],
      )
    Fabricate(:post_action, user: user, post_action_type_id: PostActionType.types[:like])

    expect { described_class.new.execute({}) }.not_to change { User.count }
    expect(User.exists?(user.id)).to eq(true)
  end

  it "deletes a user whose only like was on a deleted post" do
    SiteSetting.clean_up_inactive_users_after_days = 4
    user =
      Fabricate(
        :user,
        created_at: 5.days.ago,
        last_seen_at: 5.days.ago,
        trust_level: TrustLevel.levels[:newuser],
      )
    Fabricate(
      :post_action,
      user: user,
      post_action_type_id: PostActionType.types[:like],
      post: Fabricate(:post, deleted_at: Time.now),
    )

    expect { described_class.new.execute({}) }.to change { User.count }.by(-1)
    expect(User.exists?(user.id)).to eq(false)
  end

  it "doesn't delete a user who has a bookmark" do
    SiteSetting.clean_up_inactive_users_after_days = 4
    user =
      Fabricate(
        :user,
        created_at: 5.days.ago,
        last_seen_at: 5.days.ago,
        trust_level: TrustLevel.levels[:newuser],
      )
    Fabricate(:bookmark, user: user)

    expect { described_class.new.execute({}) }.not_to change { User.count }
    expect(User.exists?(user.id)).to eq(true)
  end

  it "supports plugins extending eligibility via the clean_up_inactive_users_query modifier" do
    SiteSetting.clean_up_inactive_users_after_days = 4

    eligible_user =
      Fabricate(
        :user,
        created_at: 5.days.ago,
        last_seen_at: 5.days.ago,
        trust_level: TrustLevel.levels[:newuser],
      )
    protected_user =
      Fabricate(
        :user,
        created_at: 5.days.ago,
        last_seen_at: 5.days.ago,
        trust_level: TrustLevel.levels[:newuser],
      )

    modifier_proc = Proc.new { |relation| relation.where.not(id: protected_user.id) }

    plugin_instance = Plugin::Instance.new
    plugin_instance.register_modifier(:clean_up_inactive_users_query, &modifier_proc)

    begin
      expect { described_class.new.execute({}) }.to change { User.count }.by(-1)
      expect(User.exists?(eligible_user.id)).to eq(false)
      expect(User.exists?(protected_user.id)).to eq(true)
    ensure
      DiscoursePluginRegistry.unregister_modifier(
        plugin_instance,
        :clean_up_inactive_users_query,
        &modifier_proc
      )
    end
  end
end

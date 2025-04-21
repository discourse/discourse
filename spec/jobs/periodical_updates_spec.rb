# frozen_string_literal: true

RSpec.describe Jobs::PeriodicalUpdates do
  fab!(:admin)
  before do
    UserAvatar.where(last_gravatar_download_attempt: nil).update_all(
      last_gravatar_download_attempt: Time.now,
    )
  end

  it "works" do
    # does not blow up, no mocks, everything is called
    Jobs::PeriodicalUpdates.new.execute(nil)
  end

  it "can rebake old posts when automatically_download_gravatars is false" do
    SiteSetting.automatically_download_gravatars = false
    post = create_post(user: admin)
    post.update_columns(baked_at: Time.new(2000, 1, 1), baked_version: -1)

    Sidekiq::Testing.fake! do
      Jobs::ProcessPost.jobs.clear

      Jobs::PeriodicalUpdates.new.execute

      jobs = Jobs::ProcessPost.jobs
      expect(jobs.length).to eq(1)

      expect(jobs[0]["queue"]).to eq("ultra_low")
    end

    post.reload
    expect(post.baked_at).to be > 1.day.ago
    baked = post.baked_at

    # does not rebake
    Jobs::PeriodicalUpdates.new.execute
    post.reload
    expect(post.baked_at).to eq_time(baked)
  end

  it "does not rebake old posts when automatically_download_gravatars is true and a valid user avatar needs updating" do
    SiteSetting.automatically_download_gravatars = true
    UserAvatar.last.update!(last_gravatar_download_attempt: nil)
    post = create_post(user: admin)
    post.update_columns(baked_at: Time.new(2000, 1, 1), baked_version: -1)

    Sidekiq::Testing.fake! do
      Jobs::ProcessPost.jobs.clear
      Jobs::PeriodicalUpdates.new.execute
      expect(Jobs::ProcessPost.jobs).to be_empty
    end
  end

  it "does not rebake old posts when there are user avatars that need updating" do
    SiteSetting.automatically_download_gravatars = true

    post = create_post(user: admin)
    post.update_columns(baked_at: Time.new(2000, 1, 1), baked_version: -1)
    UserAvatar.last.update!(last_gravatar_download_attempt: nil)

    Sidekiq::Testing.fake! do
      Jobs::ProcessPost.jobs.clear
      Jobs::PeriodicalUpdates.new.execute
      expect(Jobs::ProcessPost.jobs).to be_empty
    end
  end

  # inconsistent data will be fixed by ensure_consistency! of the relevant models
  it "rebakes old posts when there are user avatars that need updating but have inconsistent data" do
    SiteSetting.automatically_download_gravatars = true

    user_avatar_without_user = Fabricate(:user_avatar, last_gravatar_download_attempt: Time.now)
    user_avatar_without_user.user.delete
    user_without_any_email = Fabricate(:user)
    user_without_any_email.user_emails.delete_all
    user_without_primary_email = Fabricate(:user)
    user_without_primary_email.primary_email.update_column(:primary, false)

    post = create_post(user: admin)
    post.update_columns(baked_at: Time.new(2000, 1, 1), baked_version: -1)

    Sidekiq::Testing.fake! do
      Jobs::ProcessPost.jobs.clear
      Jobs::PeriodicalUpdates.new.execute
      expect(Jobs::ProcessPost.jobs.length).to eq(1)
    end
  end
end

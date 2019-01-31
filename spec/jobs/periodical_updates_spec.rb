require 'rails_helper'
require_dependency 'jobs/scheduled/periodical_updates'

describe Jobs::PeriodicalUpdates do

  it "works" do

    # does not blow up, no mocks, everything is called
    Jobs::PeriodicalUpdates.new.execute(nil)
  end

  it "can rebake old posts when automatically_download_gravatars is false" do
    SiteSetting.automatically_download_gravatars = false
    post = create_post
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
    expect(post.baked_at).to eq(baked)
  end
end

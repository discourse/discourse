# frozen_string_literal: true

RSpec.describe "Setting changes" do
  describe "#must_approve_users" do
    before { SiteSetting.must_approve_users = false }

    it "does not approve a user with associated reviewables" do
      user_pending_approval = Fabricate(:reviewable_user).target

      SiteSetting.must_approve_users = true

      expect(user_pending_approval.reload.approved?).to eq(false)
    end

    it "approves a user whose only reviewable is not pending" do
      stuck_user = Fabricate(:reviewable_user, status: Reviewable.statuses[:rejected]).target

      SiteSetting.must_approve_users = true

      expect(stuck_user.reload.approved?).to eq(true)
    end

    it "approves a user with no associated reviewables" do
      non_approved_user = Fabricate(:user, approved: false)

      SiteSetting.must_approve_users = true

      expect(non_approved_user.reload.approved?).to eq(true)
    end

    it "approves a user whose id collides with a non-user reviewable's target_id" do
      user = Fabricate(:user, approved: false)
      Fabricate(:reviewable, type: "ReviewableFlaggedPost", target_id: user.id, target_type: "Post")

      SiteSetting.must_approve_users = true

      expect(user.reload.approved?).to eq(true)
    end
  end

  describe "#reviewable_low_priority_threshold" do
    let(:new_threshold) { 5 }

    it "sets the low priority value" do
      medium_threshold = 10
      Reviewable.set_priorities(medium: medium_threshold)

      expect(Reviewable.min_score_for_priority(:low)).not_to eq(new_threshold)

      SiteSetting.reviewable_low_priority_threshold = new_threshold

      expect(Reviewable.min_score_for_priority(:low)).to eq(new_threshold)
    end

    it "does nothing if the other thresholds were not calculated" do
      Reviewable.set_priorities(medium: 0.0)

      SiteSetting.reviewable_low_priority_threshold = new_threshold

      expect(Reviewable.min_score_for_priority(:low)).not_to eq(new_threshold)
    end
  end

  describe "#title and #site_description" do
    before do
      general_category = Fabricate(:category, name: "General")
      SiteSetting.general_category_id = general_category.id
      SeedData::Topics.with_default_locale.create(site_setting_names: ["welcome_topic_id"])
    end

    it "updates the welcome topic when title changes" do
      SiteSetting.title = SecureRandom.alphanumeric

      topic = Topic.find(SiteSetting.welcome_topic_id)
      expect(topic.title).to include(SiteSetting.title)
    end

    it "updates the welcome topic when site_description changes" do
      SiteSetting.title = SecureRandom.alphanumeric
      SiteSetting.site_description = SecureRandom.alphanumeric

      topic = Topic.find(SiteSetting.welcome_topic_id)
      expect(topic.title).to include(SiteSetting.title)
      expect(topic.first_post.raw).to include(SiteSetting.title)
      expect(topic.first_post.raw).to include(SiteSetting.site_description)
    end
  end

  describe "#company_name" do
    it "does not seed legal topics" do
      expect { SiteSetting.company_name = "Company Name" }.to not_change {
        Topic.count
      }.and not_change { SiteSetting.tos_topic_id }.and not_change { SiteSetting.privacy_topic_id }
    end
  end
end

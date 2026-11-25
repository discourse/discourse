# frozen_string_literal: true

RSpec.describe AdminOnboarding do
  fab!(:owner, :admin)
  fab!(:other_admin, :admin)
  fab!(:user)

  before { SiteSetting.enable_site_owner_onboarding = true }

  describe ".complete_step" do
    def step_logs
      UserHistory.where(action: UserHistory.actions[:admin_onboarding_step_completed])
    end

    def track_ticks(&)
      MessageBus.track_publish(described_class::STEP_COMPLETED_CHANNEL, &)
    end

    it "records the step and ticks it off in the owner's checklist" do
      messages = track_ticks { described_class.complete_step("create_category", owner) }

      expect(step_logs.pluck(:subject, :acting_user_id)).to eq([["create_category", owner.id]])
      expect(messages.map(&:data)).to eq([{ step: "create_category" }])
      expect(messages.first.user_ids).to eq([owner.id])
    end

    it "counts a step completed by another admin" do
      messages = track_ticks { described_class.complete_step("create_category", other_admin) }

      expect(step_logs.pluck(:acting_user_id)).to eq([other_admin.id])
      expect(messages.first.user_ids).to eq([owner.id])
    end

    it "records each step once" do
      messages = track_ticks { 2.times { described_class.complete_step("create_category", owner) } }

      expect(step_logs.count).to eq(1)
      expect(messages.size).to eq(1)
    end

    it "ignores users who aren't admins and bots" do
      [user, Discourse.system_user, nil].each do |actor|
        described_class.complete_step("create_category", actor)
      end

      expect(step_logs).to be_empty
    end

    it "records nothing once onboarding is over" do
      SiteSetting.enable_site_owner_onboarding = false
      described_class.complete_step("create_category", owner)

      SiteSetting.enable_site_owner_onboarding = true
      owner.update!(created_at: (SiteSetting.site_owner_onboarding_max_days + 1).days.ago)
      described_class.complete_step("create_category", owner)

      expect(step_logs).to be_empty
    end

    it "ticks the checklist only after the change is committed" do
      messages =
        track_ticks do
          ActiveRecord::Base.transaction do
            described_class.complete_step("create_category", owner)
            raise ActiveRecord::Rollback
          end
        end

      expect(step_logs).to be_empty
      expect(messages).to be_empty
    end

    it "rejects a step the checklist doesn't have" do
      expect { described_class.complete_step("start_posting", owner) }.to raise_error(ArgumentError)
    end
  end
end

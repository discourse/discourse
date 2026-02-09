# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  before { SiteSetting.discourse_rewind_enabled = true }

  fab!(:user)

  let(:serializer) { CurrentUserSerializer.new(user, scope: Guardian.new(user), root: false) }

  describe "#is_rewind_active" do
    context "when in December" do
      before { freeze_time DateTime.parse("2024-12-15") }

      it "returns true for users created more than a month ago" do
        user.update!(created_at: 2.months.ago)
        expect(serializer.as_json[:is_rewind_active]).to eq(true)
      end

      it "returns false for users created less than a month ago" do
        user.update!(created_at: 2.weeks.ago)
        expect(serializer.as_json[:is_rewind_active]).to eq(false)
      end

      it "returns true for users created exactly one month ago" do
        user.update!(created_at: 1.month.ago)
        expect(serializer.as_json[:is_rewind_active]).to eq(true)
      end
    end

    context "when in January" do
      before { freeze_time DateTime.parse("2025-01-15") }

      it "returns true for users created more than a month ago" do
        user.update!(created_at: 2.months.ago)
        expect(serializer.as_json[:is_rewind_active]).to eq(true)
      end

      it "returns false for users created less than a month ago" do
        user.update!(created_at: 2.weeks.ago)
        expect(serializer.as_json[:is_rewind_active]).to eq(false)
      end
    end

    context "when outside rewind period (e.g., November)" do
      before { freeze_time DateTime.parse("2024-11-15") }

      it "returns false regardless of user age" do
        user.update!(created_at: 2.years.ago)
        expect(serializer.as_json[:is_rewind_active]).to eq(false)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe UserOptionSerializer do
  before { SiteSetting.discourse_rewind_enabled = true }

  fab!(:user)

  let(:serializer) do
    UserOptionSerializer.new(user.user_option, scope: Guardian.new(user), root: false)
  end

  def set_dismissed_at(date_string)
    user.user_option.update!(discourse_rewind_dismissed_at: DateTime.parse(date_string))
  end

  describe "#discourse_rewind_dismissed" do
    it "returns false when dismissed_at is nil" do
      expect(serializer.as_json[:discourse_rewind_dismissed]).to eq(false)
    end

    context "when in December 2024 (showing rewind 2024)" do
      before { freeze_time DateTime.parse("2024-12-15") }

      it "returns true when dismissed in Dec 2024" do
        set_dismissed_at("2024-12-01")
        expect(serializer.as_json[:discourse_rewind_dismissed]).to eq(true)
      end

      it "returns false when dismissed in Jan 2024 (was for rewind 2023)" do
        set_dismissed_at("2024-01-10")
        expect(serializer.as_json[:discourse_rewind_dismissed]).to eq(false)
      end

      it "returns false when dismissed in Dec 2023" do
        set_dismissed_at("2023-12-01")
        expect(serializer.as_json[:discourse_rewind_dismissed]).to eq(false)
      end
    end

    context "when in January 2025 (still showing rewind 2024)" do
      before { freeze_time DateTime.parse("2025-01-15") }

      it "returns true when dismissed in Dec 2024" do
        set_dismissed_at("2024-12-20")
        expect(serializer.as_json[:discourse_rewind_dismissed]).to eq(true)
      end

      it "returns true when dismissed in Jan 2025" do
        set_dismissed_at("2025-01-05")
        expect(serializer.as_json[:discourse_rewind_dismissed]).to eq(true)
      end

      it "returns false when dismissed in Jan 2024 (was for rewind 2023)" do
        set_dismissed_at("2024-01-20")
        expect(serializer.as_json[:discourse_rewind_dismissed]).to eq(false)
      end
    end
  end
end

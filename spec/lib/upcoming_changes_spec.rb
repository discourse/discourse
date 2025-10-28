# frozen_string_literal: true

RSpec.describe UpcomingChanges do
  let(:setting_name) { "enable_upload_debug_mode" }

  before do
    mock_upcoming_change_metadata(
      {
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: :pre_alpha,
          impact_type: "other",
          impact_role: "developers",
        },
        alpha_setting: {
          status: :alpha,
        },
        beta_setting: {
          status: :beta,
        },
        stable_setting: {
          status: :stable,
        },
        permanent_setting: {
          status: :permanent,
        },
      },
    )

    # There is a fixture image at spec/fixtures/images/upcoming_changes/enable_upload_debug_mode.png,
    # but normally upcoming change images are at Rails.public_path + /images/upcoming_changes/
    Rails.stubs(:public_path).returns(File.join(Rails.root, "spec", "fixtures"))
  end

  describe ".image_exists?" do
    it "returns true when the image file exists" do
      expect(described_class.image_exists?(setting_name)).to eq(true)
    end

    it "returns false when the image file does not exist" do
      expect(described_class.image_exists?("nonexistent_setting")).to eq(false)
    end
  end

  describe ".image_path" do
    it "returns the correct path for the image" do
      expect(described_class.image_path(setting_name)).to eq(
        "images/upcoming_changes/#{setting_name}.png",
      )
    end
  end

  describe ".image_data" do
    it "returns image URL, width, and height" do
      result = described_class.image_data(setting_name)

      expect(result[:url]).to eq(
        "#{Discourse.base_url}/images/upcoming_changes/#{setting_name}.png",
      )
      expect(result[:width]).to eq(244)
      expect(result[:height]).to eq(66)
    end
  end

  describe ".change_metadata" do
    it "returns the metadata hash for a setting with metadata" do
      metadata = described_class.change_metadata(setting_name)

      expect(metadata).to eq(
        {
          impact: "other,developers",
          status: :pre_alpha,
          impact_type: "other",
          impact_role: "developers",
        },
      )
    end

    it "returns an empty hash for a setting without metadata" do
      metadata = described_class.change_metadata("nonexistent_setting")

      expect(metadata).to eq({})
    end

    it "accepts string setting names" do
      metadata = described_class.change_metadata(setting_name)

      expect(metadata[:status]).to eq(:pre_alpha)
    end

    it "accepts symbol setting names" do
      metadata = described_class.change_metadata(setting_name.to_sym)

      expect(metadata[:status]).to eq(:pre_alpha)
    end
  end

  describe ".not_yet_stable?" do
    it "returns true for pre_alpha status" do
      expect(described_class.not_yet_stable?(setting_name)).to eq(true)
    end

    it "returns true for alpha status" do
      expect(described_class.not_yet_stable?("alpha_setting")).to eq(true)
    end

    it "returns true for beta status" do
      expect(described_class.not_yet_stable?("beta_setting")).to eq(true)
    end

    it "returns false for stable status" do
      expect(described_class.not_yet_stable?("stable_setting")).to eq(false)
    end

    it "returns false for permanent status" do
      expect(described_class.not_yet_stable?("permanent_setting")).to eq(false)
    end
  end

  describe ".stable_or_permanent?" do
    it "returns false for pre_alpha status" do
      expect(described_class.stable_or_permanent?(setting_name)).to eq(false)
    end

    it "returns false for alpha status" do
      expect(described_class.stable_or_permanent?("alpha_setting")).to eq(false)
    end

    it "returns false for beta status" do
      expect(described_class.stable_or_permanent?("beta_setting")).to eq(false)
    end

    it "returns true for stable status" do
      expect(described_class.stable_or_permanent?("stable_setting")).to eq(true)
    end

    it "returns true for permanent status" do
      expect(described_class.stable_or_permanent?("permanent_setting")).to eq(true)
    end
  end

  describe ".change_status_value" do
    it "returns 0 for pre_alpha status" do
      expect(described_class.change_status_value(setting_name)).to eq(0)
    end

    it "returns 100 for alpha status" do
      expect(described_class.change_status_value("alpha_setting")).to eq(100)
    end

    it "returns 200 for beta status" do
      expect(described_class.change_status_value("beta_setting")).to eq(200)
    end

    it "returns 300 for stable status" do
      expect(described_class.change_status_value("stable_setting")).to eq(300)
    end

    it "returns 500 for permanent status" do
      expect(described_class.change_status_value("permanent_setting")).to eq(500)
    end
  end

  describe ".change_status" do
    it "returns :pre_alpha for pre_alpha status" do
      expect(described_class.change_status(setting_name)).to eq(:pre_alpha)
    end

    it "returns :alpha for alpha status" do
      expect(described_class.change_status("alpha_setting")).to eq(:alpha)
    end

    it "returns :beta for beta status" do
      expect(described_class.change_status("beta_setting")).to eq(:beta)
    end

    it "returns :stable for stable status" do
      expect(described_class.change_status("stable_setting")).to eq(:stable)
    end

    it "returns :permanent for permanent status" do
      expect(described_class.change_status("permanent_setting")).to eq(:permanent)
    end
  end

  describe ".meets_or_exceeds_status?" do
    it "returns true when the change meets the required status" do
      expect(described_class.meets_or_exceeds_status?("stable_setting", :beta)).to eq(true)
      expect(described_class.meets_or_exceeds_status?("permanent_setting", :stable)).to eq(true)
    end

    it "returns false when the change does not meet the required status" do
      expect(described_class.meets_or_exceeds_status?("alpha_setting", :beta)).to eq(false)
      expect(described_class.meets_or_exceeds_status?("beta_setting", :stable)).to eq(false)
    end
  end

  describe ".history_for" do
    fab!(:admin)

    it "returns UserHistory records for the given setting" do
      UserHistory.create!(
        action: UserHistory.actions[:upcoming_change_toggled],
        subject: setting_name,
        acting_user_id: admin.id,
      )

      history = described_class.history_for(setting_name)

      expect(history.count).to eq(1)
      expect(history.first.subject).to eq(setting_name)
      expect(history.first.action).to eq(UserHistory.actions[:upcoming_change_toggled])
    end

    it "returns records ordered by created_at descending" do
      first_history =
        UserHistory.create!(
          action: UserHistory.actions[:upcoming_change_toggled],
          subject: setting_name,
          acting_user_id: admin.id,
          created_at: 2.days.ago,
        )

      second_history =
        UserHistory.create!(
          action: UserHistory.actions[:upcoming_change_toggled],
          subject: setting_name,
          acting_user_id: admin.id,
          created_at: 1.day.ago,
        )

      history = described_class.history_for(setting_name)

      expect(history.first.id).to eq(second_history.id)
      expect(history.last.id).to eq(first_history.id)
    end

    it "returns only records matching the setting name" do
      UserHistory.create!(
        action: UserHistory.actions[:upcoming_change_toggled],
        subject: setting_name,
        acting_user_id: admin.id,
      )

      UserHistory.create!(
        action: UserHistory.actions[:upcoming_change_toggled],
        subject: "different_setting",
        acting_user_id: admin.id,
      )

      history = described_class.history_for(setting_name)

      expect(history.count).to eq(1)
      expect(history.first.subject).to eq(setting_name)
    end

    it "returns only records with upcoming_change_toggled action" do
      UserHistory.create!(
        action: UserHistory.actions[:upcoming_change_toggled],
        subject: setting_name,
        acting_user_id: admin.id,
      )

      UserHistory.create!(
        action: UserHistory.actions[:change_site_setting],
        subject: setting_name,
        acting_user_id: admin.id,
      )

      history = described_class.history_for(setting_name)

      expect(history.count).to eq(1)
      expect(history.first.action).to eq(UserHistory.actions[:upcoming_change_toggled])
    end

    it "returns an empty relation when no history exists" do
      history = described_class.history_for("nonexistent_setting")

      expect(history.count).to eq(0)
      expect(history).to be_a(ActiveRecord::Relation)
    end
  end
end

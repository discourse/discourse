# frozen_string_literal: true

RSpec.describe Jobs::CheckNewFeatures do
  def build_feature_hash(id:, created_at:, discourse_version: "2.9.0.beta10")
    {
      id: id,
      user_id: 89_432,
      emoji: "👤",
      title: "New fancy feature!",
      description: "",
      link: "https://meta.discourse.org/t/-/238821",
      created_at: created_at.iso8601,
      updated_at: (created_at + 1.minute).iso8601,
      discourse_version: discourse_version,
    }
  end

  def stub_new_features_endpoint(*features)
    stub_request(:get, DiscourseUpdates.new_features_endpoint).to_return(
      status: 200,
      body: JSON.dump(features),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  fab!(:admin1, :admin)
  fab!(:admin2, :admin)

  let(:feature1) do
    build_feature_hash(id: 35, created_at: 3.days.ago, discourse_version: "2.8.1.beta12")
  end

  let(:feature2) do
    build_feature_hash(id: 34, created_at: 2.days.ago, discourse_version: "2.8.1.beta13")
  end

  let(:pending_feature) do
    build_feature_hash(id: 37, created_at: 1.day.ago, discourse_version: "2.8.1.beta14")
  end

  before do
    DiscourseUpdates.stubs(:current_version).returns("2.8.1.beta13")
    freeze_time
    stub_new_features_endpoint(feature1, feature2, pending_feature)
  end

  after { DiscourseUpdates.clean_state }

  it "backfills last viewed feature for admins who don't have last viewed feature" do
    DiscourseUpdates.stubs(:current_version).returns("2.8.1.beta12")
    DiscourseUpdates.update_new_features([feature1].to_json)
    DiscourseUpdates.bump_last_viewed_feature_date(admin1.id, Time.zone.now.iso8601)

    described_class.new.execute({})

    expect(DiscourseUpdates.get_last_viewed_feature_date(admin2.id).iso8601).to eq(
      feature1[:created_at],
    )
    expect(DiscourseUpdates.get_last_viewed_feature_date(admin1.id).iso8601).to eq(
      Time.zone.now.iso8601,
    )
  end

  it "notifies admins about new features that are available in the site's version" do
    Notification.destroy_all

    described_class.new.execute({})

    expect(
      admin1
        .notifications
        .where(notification_type: Notification.types[:new_features], read: false)
        .count,
    ).to eq(1)
    expect(
      admin2
        .notifications
        .where(notification_type: Notification.types[:new_features], read: false)
        .count,
    ).to eq(1)
  end

  context "when a permanent upcoming change is merged into an empty new-features feed" do
    before do
      UpcomingChanges.stubs(:image_data).returns(
        {
          url: "#{Discourse.base_url}/images/upcoming_changes/enable_upload_debug_mode.png",
          width: 244,
          height: 66,
          file_path: file_from_fixtures("logo.png", "images").path,
        },
      )
      stub_new_features_endpoint(feature1)
    end

    after { clear_mocked_upcoming_change_metadata }

    it "notifies admins and bumps last_viewed_feature_date from the status_changed time" do
      Notification.destroy_all

      status_changed_at = 1.day.ago
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :permanent,
            impact_type: "other",
            impact_role: "developers",
            learn_more_url: "https://meta.discourse.org/t/-/1234",
          },
        },
      )
      event =
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: "enable_upload_debug_mode",
          event_data: {
            "previous_value" => "stable",
            "new_value" => "permanent",
          },
          created_at: status_changed_at,
        )

      described_class.new.execute({})

      expect(
        admin1
          .notifications
          .where(notification_type: Notification.types[:new_features], read: false)
          .count,
      ).to eq(1)
      expect(
        admin2
          .notifications
          .where(notification_type: Notification.types[:new_features], read: false)
          .count,
      ).to eq(1)

      status_changed_at_db = event.reload.created_at
      expect(DiscourseUpdates.get_last_viewed_feature_date(admin1.id)).to be_within_one_second_of(
        status_changed_at_db,
      )
      expect(DiscourseUpdates.get_last_viewed_feature_date(admin2.id)).to be_within_one_second_of(
        status_changed_at_db,
      )
    end
  end

  context "when persisted feed is older than a permanent upcoming change" do
    let(:feature_stale) do
      build_feature_hash(id: 99, created_at: 3.days.ago, discourse_version: "2.8.1.beta12")
    end

    let(:feature_newer_than_uc) do
      build_feature_hash(id: 100, created_at: 1.day.ago, discourse_version: "2.8.1.beta13")
    end

    before do
      UpcomingChanges.stubs(:image_data).returns(
        {
          url: "#{Discourse.base_url}/images/upcoming_changes/enable_upload_debug_mode.png",
          width: 244,
          height: 66,
          file_path: file_from_fixtures("logo.png", "images").path,
        },
      )
      stub_new_features_endpoint(feature_stale)
    end

    after { clear_mocked_upcoming_change_metadata }

    it "seeds last_viewed to the UC when the fetch adds nothing newer, without notifying" do
      Notification.destroy_all

      uc_became_permanent_at = 2.days.ago
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :permanent,
            impact_type: "other",
            impact_role: "developers",
            learn_more_url: "https://meta.discourse.org/t/-/1234",
          },
        },
      )
      UpcomingChangeEvent.create!(
        event_type: :status_changed,
        upcoming_change_name: "enable_upload_debug_mode",
        event_data: {
          "previous_value" => "stable",
          "new_value" => "permanent",
        },
        created_at: uc_became_permanent_at,
      )

      DiscourseUpdates.update_new_features([feature_stale].to_json)

      described_class.new.execute({})

      expect(
        admin1.notifications.where(
          notification_type: Notification.types[:new_features],
          read: false,
        ),
      ).to be_empty
      expect(
        admin2.notifications.where(
          notification_type: Notification.types[:new_features],
          read: false,
        ),
      ).to be_empty
      expect(DiscourseUpdates.get_last_viewed_feature_date(admin1.id)).to be_within_one_second_of(
        uc_became_permanent_at,
      )
      expect(DiscourseUpdates.get_last_viewed_feature_date(admin2.id)).to be_within_one_second_of(
        uc_became_permanent_at,
      )
    end

    it "notifies and bumps last_viewed to a new feed item newer than the UC" do
      Notification.destroy_all

      uc_became_permanent_at = 2.days.ago
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :permanent,
            impact_type: "other",
            impact_role: "developers",
            learn_more_url: "https://meta.discourse.org/t/-/1234",
          },
        },
      )
      UpcomingChangeEvent.create!(
        event_type: :status_changed,
        upcoming_change_name: "enable_upload_debug_mode",
        event_data: {
          "previous_value" => "stable",
          "new_value" => "permanent",
        },
        created_at: uc_became_permanent_at,
      )

      DiscourseUpdates.update_new_features([feature_stale].to_json)
      stub_new_features_endpoint(feature_newer_than_uc, feature_stale)

      described_class.new.execute({})

      expect(
        admin1
          .notifications
          .where(notification_type: Notification.types[:new_features], read: false)
          .count,
      ).to eq(1)
      expect(
        admin2
          .notifications
          .where(notification_type: Notification.types[:new_features], read: false)
          .count,
      ).to eq(1)
      newer_time = Time.zone.parse(feature_newer_than_uc[:created_at])
      expect(DiscourseUpdates.get_last_viewed_feature_date(admin1.id)).to be_within_one_second_of(
        newer_time,
      )
      expect(DiscourseUpdates.get_last_viewed_feature_date(admin2.id)).to be_within_one_second_of(
        newer_time,
      )
    end
  end

  it "consolidates new features notifications" do
    Notification.destroy_all

    described_class.new.execute({})

    notification =
      admin1
        .notifications
        .where(notification_type: Notification.types[:new_features], read: false)
        .first
    expect(notification).to be_present

    DiscourseUpdates.stubs(:current_version).returns("2.8.1.beta14")
    described_class.new.execute({})

    # old notification is destroyed
    expect(Notification.find_by(id: notification.id)).to eq(nil)

    notification =
      admin1
        .notifications
        .where(notification_type: Notification.types[:new_features], read: false)
        .first
    # new notification is created
    expect(notification).to be_present
  end

  it "doesn't notify admins about features they've already seen" do
    Notification.destroy_all
    DiscourseUpdates.bump_last_viewed_feature_date(admin1.id, feature2[:created_at])

    described_class.new.execute({})

    expect(admin1.notifications.count).to eq(0)
    expect(
      admin2.notifications.where(notification_type: Notification.types[:new_features]).count,
    ).to eq(1)
  end
end

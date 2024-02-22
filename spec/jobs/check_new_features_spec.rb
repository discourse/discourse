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
      updated_at: (created_at + 1.minutes).iso8601,
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

  fab!(:admin1) { Fabricate(:admin) }
  fab!(:admin2) { Fabricate(:admin) }

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

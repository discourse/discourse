# frozen_string_literal: true

RSpec.describe Jobs::RefreshLatestNewFeature do
  let(:newest_date) { 5.minutes.ago }

  before { UpcomingChanges.stubs(:permanent_upcoming_changes).returns([]) }

  after { DiscourseUpdates.clean_state }

  it "derives the latest new feature timestamp from the stored feed" do
    Discourse.redis.set(
      "new_features",
      MultiJson.dump(
        [
          { "emoji" => "🤾", "title" => "Old Feature", "created_at" => 40.minutes.ago },
          { "emoji" => "🙈", "title" => "Newest Feature", "created_at" => newest_date },
        ],
      ),
    )

    described_class.new.execute({})

    expect(DiscourseUpdates.latest_new_feature_created_at).to be_within(1.second).of(newest_date)
  end

  it "clears the timestamp when there is nothing to show" do
    Discourse.redis.set("latest_new_feature_created_at", 1.hour.ago.iso8601)
    Discourse.redis.set("new_features", MultiJson.dump([]))

    described_class.new.execute({})

    expect(DiscourseUpdates.latest_new_feature_created_at).to be_nil
  end
end

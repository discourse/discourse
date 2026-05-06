# frozen_string_literal: true

RSpec.describe DiscourseUpdates do
  # DiscourseUpdates merges against UpcomingChanges.permanent_upcoming_changes; stub it
  # so these examples do not depend on which settings are marked permanent in
  # site_settings.yml.
  def stub_permanent_upcoming_changes!(changes)
    UpcomingChanges.stubs(:permanent_upcoming_changes).returns(changes)
  end

  def stub_merge_uc_example_status!(uc_status)
    if uc_status == :permanent
      stub_permanent_upcoming_changes!(permanent_upcoming_changes)
    else
      stub_permanent_upcoming_changes!([])
    end
  end

  def stub_data(latest, missing, critical, updated_at)
    DiscourseUpdates.latest_version = latest
    DiscourseUpdates.missing_versions_count = missing
    DiscourseUpdates.critical_updates_available = critical
    DiscourseUpdates.updated_at = updated_at
  end

  subject(:version) { DiscourseUpdates.check_version }

  let(:permanent_upcoming_changes) do
    [
      {
        setting: :enable_upload_debug_mode,
        humanized_name: "Enable upload debug mode",
        description: "Debug uploads.",
        upcoming_change: {
          learn_more_url: "https://meta.discourse.org/t/-/1234",
          image: {
            url: "#{Discourse.base_url}/images/upcoming_changes/enable_upload_debug_mode.png",
          },
        },
      },
    ]
  end

  context "when version check was done at the current installed version" do
    before { DiscourseUpdates.last_installed_version = Discourse::VERSION::STRING }

    context "when a good version check request happened recently" do
      context "when server is up-to-date" do
        let(:time) { 12.hours.ago }
        before { stub_data(Discourse::VERSION::STRING, 0, false, time) }

        it "returns all the version fields" do
          expect(version.latest_version).to eq(Discourse::VERSION::STRING)
          expect(version.missing_versions_count).to eq(0)
          expect(version.critical_updates).to eq(false)
          expect(version.installed_version).to eq(Discourse::VERSION::STRING)
          expect(version.stale_data).to eq(false)
        end

        it "returns the timestamp of the last version check" do
          expect(version.updated_at).to be_within_one_second_of(time)
        end
      end

      context "when server is not up-to-date" do
        let(:time) { 12.hours.ago }
        before { stub_data("0.9.0", 2, false, time) }

        it "returns all the version fields" do
          expect(version.latest_version).to eq("0.9.0")
          expect(version.missing_versions_count).to eq(2)
          expect(version.critical_updates).to eq(false)
          expect(version.installed_version).to eq(Discourse::VERSION::STRING)
        end

        it "returns the timestamp of the last version check" do
          expect(version.updated_at).to be_within_one_second_of(time)
        end
      end
    end

    context "when a version check has never been performed" do
      before { stub_data(nil, nil, false, nil) }

      it "returns the installed version" do
        expect(version.installed_version).to eq(Discourse::VERSION::STRING)
      end

      it "indicates that version check has not been performed" do
        expect(version.updated_at).to eq(nil)
        expect(version.stale_data).to eq(true)
      end

      it "does not return latest version info" do
        expect(version.latest_version).to eq(nil)
        expect(version.missing_versions_count).to eq(nil)
        expect(version.critical_updates).to eq(nil)
      end

      it "queues a version check" do
        expect_enqueued_with(job: :call_discourse_hub) { version }
      end
    end

    # These cases should never happen anymore, but keep the specs to be sure
    # they're handled in a sane way.
    context "with old version check data" do
      shared_examples "queue version check and report that version is ok" do
        it "queues a version check" do
          expect_enqueued_with(job: :call_discourse_hub) { version }
        end

        it "reports 0 missing versions" do
          expect(version.missing_versions_count).to eq(0)
        end

        it "reports that a version check will be run soon" do
          expect(version.version_check_pending).to eq(true)
        end
      end

      context "when installed is latest" do
        before { stub_data(Discourse::VERSION::STRING, 1, false, 8.hours.ago) }
        include_examples "queue version check and report that version is ok"
      end

      context "when installed does not match latest version, but missing_versions_count is 0" do
        before { stub_data("0.10.10.123", 0, false, 8.hours.ago) }
        include_examples "queue version check and report that version is ok"
      end
    end
  end

  context "when version check was done at a different installed version" do
    before { DiscourseUpdates.last_installed_version = "0.9.1" }

    shared_examples "when last_installed_version is old" do
      it "queues a version check" do
        expect_enqueued_with(job: :call_discourse_hub) { version }
      end

      it "reports 0 missing versions" do
        expect(version.missing_versions_count).to eq(0)
      end

      it "reports that a version check will be run soon" do
        expect(version.version_check_pending).to eq(true)
      end
    end

    context "when missing_versions_count is 0" do
      before { stub_data("0.9.7", 0, false, 8.hours.ago) }
      include_examples "when last_installed_version is old"
    end

    context "when missing_versions_count is not 0" do
      before { stub_data("0.9.7", 1, false, 8.hours.ago) }
      include_examples "when last_installed_version is old"
    end
  end

  describe "new features" do
    fab!(:admin)
    fab!(:admin2, :admin)
    let!(:last_item_date) { 5.minutes.ago }
    let!(:sample_features) do
      [
        {
          "emoji" => "🤾",
          "title" => "Super Fruits",
          "description" => "Taste explosion!",
          "created_at" => 40.minutes.ago,
        },
        {
          "emoji" => "🙈",
          "title" => "Fancy Legumes",
          "description" => "Magic legumes!",
          "created_at" => 15.minutes.ago,
        },
        {
          "emoji" => "🤾",
          "title" => "Quality Veggies",
          "description" => "Green goodness!",
          "created_at" => last_item_date,
        },
      ]
    end

    before(:each) do
      stub_permanent_upcoming_changes!([])

      Discourse.redis.del "new_features_last_seen_user_#{admin.id}"
      Discourse.redis.del "new_features_last_seen_user_#{admin2.id}"
      Discourse.redis.set("new_features", MultiJson.dump(sample_features))
    end

    after { DiscourseUpdates.clean_state }

    it "returns all items on the first run" do
      result = DiscourseUpdates.new_features

      expect(result.length).to eq(3)
      expect(result[2]["title"]).to eq("Super Fruits")
    end

    it "correctly marks unseen items by user" do
      DiscourseUpdates.stubs(:new_features_last_seen).with(admin.id).returns(10.minutes.ago)
      DiscourseUpdates.stubs(:new_features_last_seen).with(admin2.id).returns(30.minutes.ago)

      expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(true)
      expect(DiscourseUpdates.has_unseen_features?(admin2.id)).to eq(true)
    end

    it "can mark features as seen for a given user" do
      expect(DiscourseUpdates.has_unseen_features?(admin.id)).to be_truthy

      DiscourseUpdates.mark_new_features_as_seen(admin.id)
      expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(false)

      # doesn't affect another user
      expect(DiscourseUpdates.has_unseen_features?(admin2.id)).to eq(true)
    end

    it "correctly sees newly added features as unseen" do
      DiscourseUpdates.mark_new_features_as_seen(admin.id)
      expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(false)
      expect(DiscourseUpdates.new_features_last_seen(admin.id)).to be_within(1.second).of(
        last_item_date,
      )

      updated_features = [
        { "emoji" => "🤾", "title" => "Brand New Item", "created_at" => 2.minutes.ago },
      ]
      updated_features += sample_features

      DiscourseUpdates.update_new_features(MultiJson.dump(updated_features))
      expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(true)
    end

    it "filters out entries that raise while validating feed metadata" do
      malformed_features = [
        { "emoji" => "🤾", "title" => "Bells", "created_at" => 2.days.ago },
        {
          "emoji" => "🙈",
          "title" => "Broken plugin row",
          "created_at" => 1.day.ago,
          "discourse_version" => "blah",
        },
      ]

      Discourse.redis.set("new_features", MultiJson.dump(malformed_features))
      Discourse
        .expects(:has_needed_version?)
        .with(Discourse::VERSION::STRING, "blah")
        .once
        .raises(StandardError)

      result = DiscourseUpdates.new_features
      expect(result.map { |item| item["title"] }).to eq(["Bells"])
    end

    it "correctly shows features by Discourse version" do
      features_with_versions = [
        { "emoji" => "🤾", "title" => "Bells", "created_at" => 2.days.ago },
        {
          "emoji" => "🙈",
          "title" => "Whistles",
          "created_at" => 120.minutes.ago,
          :discourse_version => "2.6.0.beta1",
        },
        {
          "emoji" => "🙈",
          "title" => "Confetti",
          "created_at" => 15.minutes.ago,
          :discourse_version => "2.7.0.beta2",
        },
        {
          "emoji" => "🤾",
          "title" => "Not shown yet",
          "created_at" => 10.minutes.ago,
          :discourse_version => "2.7.0.beta5",
        },
        {
          "emoji" => "🤾",
          "title" => "Not shown yet (beta < stable)",
          "created_at" => 10.minutes.ago,
          :discourse_version => "2.7.0",
        },
        {
          "emoji" => "🤾",
          "title" => "Ignore invalid version",
          "created_at" => 10.minutes.ago,
          :discourse_version => "invalid-version",
        },
      ]

      Discourse.redis.set("new_features", MultiJson.dump(features_with_versions))
      DiscourseUpdates.last_installed_version = "2.7.0.beta2"
      result = DiscourseUpdates.new_features

      expect(result.length).to eq(3)
      expect(result[0]["title"]).to eq("Confetti")
      expect(result[1]["title"]).to eq("Whistles")
      expect(result[2]["title"]).to eq("Bells")
    end

    it "correctly shows features by commit hash" do
      features_with_versions = [
        { "emoji" => "🤾", "title" => "Bells", "created_at" => 2.days.ago },
        {
          "emoji" => "🙈",
          "title" => "Whistles",
          "created_at" => 120.minutes.ago,
          "discourse_version" => "208cc7b0dd4bcd134297ce076e7263d2898740e9",
        },
        {
          "emoji" => "🙈",
          "title" => "Confetti",
          "created_at" => 15.minutes.ago,
          "discourse_version" => "05a7fc954a620800ee99ecdbabcfd41572706674",
        },
      ]

      GitUtils.stubs(:has_commit?).with("208cc7b0dd4bcd134297ce076e7263d2898740e9").returns(true)
      GitUtils.stubs(:has_commit?).with("05a7fc954a620800ee99ecdbabcfd41572706674").returns(false)

      Discourse.redis.set("new_features", MultiJson.dump(features_with_versions))
      result = DiscourseUpdates.new_features

      expect(result.length).to eq(2)
      expect(result[0]["title"]).to eq("Whistles")
      expect(result[1]["title"]).to eq("Bells")
    end

    it "correctly shows features when related plugins are installed" do
      Discourse.stubs(:plugins_by_name).returns({ "discourse-ai" => true })

      features_with_versions = [
        {
          "emoji" => "🤾",
          "title" => "Bells",
          "created_at" => 2.days.ago,
          "plugin_name" => "discourse-ai",
        },
        { "emoji" => "🙈", "title" => "Whistles", "created_at" => 3.days.ago, "plugin_name" => "" },
        {
          "emoji" => "🙈",
          "title" => "Confetti",
          "created_at" => 4.days.ago,
          "plugin_name" => "uninstalled-plugin",
        },
      ]

      Discourse.redis.set("new_features", MultiJson.dump(features_with_versions))
      DiscourseUpdates.last_installed_version = "2.7.0.beta2"
      result = DiscourseUpdates.new_features

      expect(result.length).to eq(2)
      expect(result[0]["title"]).to eq("Bells")
      expect(result[1]["title"]).to eq("Whistles")
    end

    it "correctly refetches features if force_refresh is used" do
      DiscourseUpdates.expects(:update_new_features).once
      result = DiscourseUpdates.new_features
      expect(result.length).to eq(3)
      result = DiscourseUpdates.new_features(force_refresh: true)
      expect(result.length).to eq(3)
    end

    context "when the only unseen item is an injected permanent upcoming change" do
      before do
        Discourse.redis.del("new_features_last_seen_user_#{admin.id}")
        Discourse.redis.set("new_features", MultiJson.dump([]))

        stub_permanent_upcoming_changes!(permanent_upcoming_changes)

        UpcomingChanges.stubs(:image_exists?).returns(true)
        UpcomingChanges.stubs(:image_data).returns(
          {
            url: "#{Discourse.base_url}/images/upcoming_changes/enable_upload_debug_mode.png",
            width: 244,
            height: 66,
          },
        )
      end

      it "marks the injected item as seen" do
        freeze_time
        expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(true)
        DiscourseUpdates.mark_new_features_as_seen(admin.id)
        expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(false)
      end
    end
  end

  describe ".latest_new_feature_created_at" do
    let!(:newest_date) { 5.minutes.ago }
    let!(:sample_features) do
      [
        { "emoji" => "🤾", "title" => "Old Feature", "created_at" => 40.minutes.ago },
        { "emoji" => "🙈", "title" => "Middle Feature", "created_at" => 15.minutes.ago },
        { "emoji" => "🤾", "title" => "Newest Feature", "created_at" => newest_date },
      ]
    end

    before do
      stub_permanent_upcoming_changes!([])
      Discourse.redis.set("new_features", MultiJson.dump(sample_features))
    end

    after { DiscourseUpdates.clean_state }

    it "returns the max created_at from merged features" do
      result = DiscourseUpdates.latest_new_feature_created_at
      expect(result).to be_within(1.second).of(newest_date)
    end

    it "caches the result in Redis on subsequent calls" do
      DiscourseUpdates.latest_new_feature_created_at

      Discourse.redis.set("new_features", MultiJson.dump([]))
      result = DiscourseUpdates.latest_new_feature_created_at
      expect(result).to be_within(1.second).of(newest_date)
    end

    it "returns nil when no features exist" do
      Discourse.redis.set("new_features", MultiJson.dump([]))
      expect(DiscourseUpdates.latest_new_feature_created_at).to be_nil
    end

    it "is invalidated by update_new_features" do
      DiscourseUpdates.latest_new_feature_created_at

      new_date = 1.minute.ago
      new_features = [{ "emoji" => "🤾", "title" => "Brand New", "created_at" => new_date }]
      DiscourseUpdates.update_new_features(MultiJson.dump(new_features))

      result = DiscourseUpdates.latest_new_feature_created_at
      expect(result).to be_within(1.second).of(new_date)
    end

    it "is invalidated by clean_state" do
      DiscourseUpdates.latest_new_feature_created_at
      expect(Discourse.redis.get("latest_new_feature_created_at")).to be_present

      DiscourseUpdates.clean_state
      expect(Discourse.redis.get("latest_new_feature_created_at")).to be_nil
    end
  end

  describe "has_unseen_features? caching" do
    fab!(:admin)
    let!(:feature_date) { 5.minutes.ago }
    let!(:sample_features) do
      [{ "emoji" => "🤾", "title" => "A Feature", "created_at" => feature_date }]
    end

    before do
      stub_permanent_upcoming_changes!([])
      Discourse.redis.set("new_features", MultiJson.dump(sample_features))
    end

    after { DiscourseUpdates.clean_state }

    it "uses the cached timestamp instead of recomputing on repeated calls" do
      DiscourseUpdates.latest_new_feature_created_at

      Discourse.redis.set("new_features", "invalid json")
      expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(true)
    end

    it "returns false when the latest feature timestamp equals last_seen" do
      freeze_time do
        Discourse.redis.set("new_features_last_seen_user_#{admin.id}", feature_date.iso8601)
        expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(false)
      end
    end
  end

  describe ".merge_new_features_with_upcoming_changes" do
    def feature_for_uc_setting(features)
      features.find { |f| f[:upcoming_change_setting_name].to_s == "enable_upload_debug_mode" }
    end

    before do
      UpcomingChanges.stubs(:image_exists?).returns(true)
      UpcomingChanges.stubs(:image_data).returns(
        {
          url: "#{Discourse.base_url}/images/upcoming_changes/enable_upload_debug_mode.png",
          width: 244,
          height: 66,
          file_path: file_from_fixtures("logo.png", "images").path,
        },
      )
    end

    context "when there are no permanent upcoming changes" do
      before { stub_merge_uc_example_status!(:beta) }

      it "returns the same new_features array without modification" do
        features = [{ title: "Feed item", description: "From meta", created_at: 1.hour.ago.to_s }]

        result = described_class.merge_new_features_with_upcoming_changes(features)
        expect(result).to eq(features)
      end
    end

    context "when the feed already includes a feature for an upcoming change" do
      before { stub_merge_uc_example_status!(:permanent) }

      let(:upcoming_change_setting_name) { "enable_upload_debug_mode" }
      let(:feed_feature) do
        {
          title: "Official feed title",
          description: "Marketing copy from the new features feed",
          link: "https://meta.discourse.org/t/feed-release-note",
          screenshot_url: "https://meta.discourse.org/feed-screenshot.png",
          created_at: 1.week.ago.to_s,
          updated_at: 1.week.ago.to_s,
          released_at: 1.week.ago.to_s,
          upcoming_change_setting_name: upcoming_change_setting_name,
        }
      end

      context "when the upcoming change is permanent" do
        it "keeps the feed row and does not inject a duplicate from the UC" do
          new_features = [feed_feature.deep_dup]
          result = described_class.merge_new_features_with_upcoming_changes(new_features)

          expect(result.map { |r| r[:upcoming_change_setting_name] }).to include(
            "enable_upload_debug_mode",
          )
          row = feature_for_uc_setting(result)
          expect(row[:title]).to eq("Official feed title")
          expect(row[:description]).to eq("Marketing copy from the new features feed")
          expect(row[:link]).to eq("https://meta.discourse.org/t/feed-release-note")
          expect(row[:screenshot_url]).to eq("https://meta.discourse.org/feed-screenshot.png")
          expect(row[:upcoming_change_setting_name]).to eq("enable_upload_debug_mode")
        end
      end

      context "when the upcoming change is not permanent" do
        before { stub_merge_uc_example_status!(:beta) }

        it "excludes the item from the new features feed" do
          new_features = [feed_feature.deep_dup]
          result = described_class.merge_new_features_with_upcoming_changes(new_features)
          expect(result.map { |r| r[:upcoming_change_setting_name] }).not_to include(
            :enable_upload_debug_mode,
          )
        end
      end

      context "when this site does not have any permanent upcoming changes" do
        before { stub_merge_uc_example_status!(:beta) }

        it "excludes the feed item with the upcoming_change_setting_name" do
          new_features = [feed_feature.deep_dup]
          result = described_class.merge_new_features_with_upcoming_changes(new_features)
          expect(result.map { |r| r[:upcoming_change_setting_name] }).not_to include(
            :enable_upload_debug_mode,
          )
        end
      end

      it "uses the status_changed event time when the UC became permanent" do
        freeze_time
        event_time = 3.days.ago
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: "enable_upload_debug_mode",
          event_data: {
            "previous_value" => "stable",
            "new_value" => "permanent",
          },
          created_at: event_time,
        )

        result = described_class.merge_new_features_with_upcoming_changes([])
        feature = feature_for_uc_setting(result)

        expect(feature[:created_at]).to eq_time(event_time)
        expect(feature[:updated_at]).to eq_time(event_time)
        expect(feature[:released_at]).to eq_time(event_time)
      end

      it "uses the latest status_changed-to-permanent event when several exist" do
        freeze_time
        older = 5.days.ago
        newer = 1.day.ago
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: "enable_upload_debug_mode",
          event_data: {
            "previous_value" => "beta",
            "new_value" => "permanent",
          },
          created_at: older,
        )
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: "enable_upload_debug_mode",
          event_data: {
            "previous_value" => "stable",
            "new_value" => "permanent",
          },
          created_at: newer,
        )

        result = described_class.merge_new_features_with_upcoming_changes([])

        expect(feature_for_uc_setting(result)[:created_at]).to eq_time(newer)
      end

      it "falls back to the current time when no matching event exists" do
        freeze_time do
          result = described_class.merge_new_features_with_upcoming_changes([])

          expect(feature_for_uc_setting(result)[:created_at]).to eq_time(Time.zone.now)
        end
      end

      it "ignores status_changed events that did not transition to permanent" do
        freeze_time do
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: "enable_upload_debug_mode",
            event_data: {
              "previous_value" => "experimental",
              "new_value" => "stable",
            },
          )

          result = described_class.merge_new_features_with_upcoming_changes([])

          expect(feature_for_uc_setting(result)[:created_at]).to eq_time(Time.zone.now)
        end
      end
    end
  end

  describe "#get_last_viewed_feature_date" do
    fab!(:user)

    it "returns an ActiveSupport::TimeWithZone object" do
      time = Time.zone.parse("2022-12-13T21:33:59Z")
      DiscourseUpdates.bump_last_viewed_feature_date(user.id, time)
      expect(DiscourseUpdates.get_last_viewed_feature_date(user.id)).to eq(time)
    end
  end
end

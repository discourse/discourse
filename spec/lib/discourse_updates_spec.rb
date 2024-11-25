# frozen_string_literal: true

RSpec.describe DiscourseUpdates do
  def stub_data(latest, missing, critical, updated_at)
    DiscourseUpdates.latest_version = latest
    DiscourseUpdates.missing_versions_count = missing
    DiscourseUpdates.critical_updates_available = critical
    DiscourseUpdates.updated_at = updated_at
  end

  subject(:version) { DiscourseUpdates.check_version }

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
    fab!(:admin2) { Fabricate(:admin) }
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

      Discourse.redis.set("new_features", MultiJson.dump(updated_features))
      expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(true)
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

    it "correctly shows features with correct boolean experimental site settings" do
      features_with_versions = [
        {
          "emoji" => "🤾",
          "title" => "Bells",
          "created_at" => 2.days.ago,
          "experiment_setting" => "enable_mobile_theme",
        },
        {
          "emoji" => "🙈",
          "title" => "Whistles",
          "created_at" => 3.days.ago,
          "experiment_setting" => "default_theme_id",
        },
        {
          "emoji" => "🙈",
          "title" => "Confetti",
          "created_at" => 4.days.ago,
          "experiment_setting" => "wrong value",
        },
      ]

      Discourse.redis.set("new_features", MultiJson.dump(features_with_versions))
      DiscourseUpdates.last_installed_version = "2.7.0.beta2"
      result = DiscourseUpdates.new_features

      expect(result.length).to eq(3)
      expect(result[0]["experiment_setting"]).to eq("enable_mobile_theme")
      expect(result[1]["experiment_setting"]).to be_nil
      expect(result[2]["experiment_setting"]).to be_nil
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

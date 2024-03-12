# frozen_string_literal: true

RSpec.describe AdminDashboardData do
  after do
    AdminDashboardData.reset_problem_checks
    Discourse.redis.flushdb
  end

  describe "#fetch_problems" do
    describe "adding problem messages" do
      it "adds the message and returns it when the problems are fetched" do
        AdminDashboardData.add_problem_message("dashboard.bad_favicon_url")
        problems = AdminDashboardData.fetch_problems.map(&:to_s)
        expect(problems).to include(
          I18n.t("dashboard.bad_favicon_url", { base_path: Discourse.base_path }),
        )
      end

      it "does not allow adding of arbitrary problem messages, they must exist in AdminDashboardData.problem_messages" do
        AdminDashboardData.add_problem_message("errors.messages.invalid")
        problems = AdminDashboardData.fetch_problems.map(&:to_s)
        expect(problems).not_to include(I18n.t("errors.messages.invalid"))
      end
    end

    describe "adding new checks" do
      it "calls the passed block" do
        AdminDashboardData.add_problem_check { "a problem was found" }

        problems = AdminDashboardData.fetch_problems
        expect(problems.map(&:to_s)).to include("a problem was found")
      end

      it "calls the passed method" do
        klass =
          Class.new(AdminDashboardData) do
            def my_test_method
              "a problem was found"
            end
          end

        klass.add_problem_check :my_test_method

        problems = klass.fetch_problems
        expect(problems.map(&:to_s)).to include("a problem was found")
      end
    end
  end

  describe "adding scheduled checks" do
    it "does not add duplicate problems with the same identifier" do
      prob1 = AdminDashboardData::Problem.new("test problem", identifier: "test")
      prob2 = AdminDashboardData::Problem.new("test problem 2", identifier: "test")
      AdminDashboardData.add_found_scheduled_check_problem(prob1)
      AdminDashboardData.add_found_scheduled_check_problem(prob2)
      expect(AdminDashboardData.load_found_scheduled_check_problems.map(&:to_s)).to eq(
        ["test problem"],
      )
    end

    it "does not error when loading malformed problems saved in redis" do
      Discourse.redis.rpush(AdminDashboardData::SCHEDULED_PROBLEM_STORAGE_KEY, "{ 'badjson")
      expect(AdminDashboardData.load_found_scheduled_check_problems).to eq([])
    end

    it "clears a specific problem by identifier" do
      prob1 = AdminDashboardData::Problem.new("test problem 1", identifier: "test")
      AdminDashboardData.add_found_scheduled_check_problem(prob1)
      AdminDashboardData.clear_found_problem("test")
      expect(AdminDashboardData.load_found_scheduled_check_problems).to eq([])
    end

    it "defaults to low priority, and uses low priority if an invalid priority is passed" do
      prob1 = AdminDashboardData::Problem.new("test problem 1")
      prob2 = AdminDashboardData::Problem.new("test problem 2", priority: "superbad")
      expect(prob1.priority).to eq("low")
      expect(prob2.priority).to eq("low")
    end
  end

  describe "stats cache" do
    include_examples "stats cacheable"
  end

  describe "#problem_message_check" do
    let(:key) { AdminDashboardData.problem_messages.first }

    after { described_class.clear_problem_message(key) }

    it "returns nil if message has not been added" do
      expect(described_class.problem_message_check(key)).to be_nil
    end

    it "returns a message if it was added" do
      described_class.add_problem_message(key)
      expect(described_class.problem_message_check(key)).to eq(
        I18n.t(key, base_path: Discourse.base_path),
      )
    end

    it "returns a message if it was added with an expiry" do
      described_class.add_problem_message(key, 300)
      expect(described_class.problem_message_check(key)).to eq(
        I18n.t(key, base_path: Discourse.base_path),
      )
    end
  end

  describe "sidekiq_check" do
    subject(:check) { described_class.new.sidekiq_check }

    it "returns nil when sidekiq processed a job recently" do
      Jobs.stubs(:last_job_performed_at).returns(1.minute.ago)
      Jobs.stubs(:queued).returns(0)
      expect(check).to be_nil
    end

    it "returns nil when last job processed was a long time ago, but no jobs are queued" do
      Jobs.stubs(:last_job_performed_at).returns(7.days.ago)
      Jobs.stubs(:queued).returns(0)
      expect(check).to be_nil
    end

    it "returns nil when no jobs have ever been processed, but no jobs are queued" do
      Jobs.stubs(:last_job_performed_at).returns(nil)
      Jobs.stubs(:queued).returns(0)
      expect(check).to be_nil
    end

    it "returns a string when no jobs were processed recently and some jobs are queued" do
      Jobs.stubs(:last_job_performed_at).returns(20.minutes.ago)
      Jobs.stubs(:queued).returns(1)
      expect(check).to_not be_nil
    end

    it "returns a string when no jobs have ever been processed, and some jobs are queued" do
      Jobs.stubs(:last_job_performed_at).returns(nil)
      Jobs.stubs(:queued).returns(1)
      expect(check).to_not be_nil
    end
  end

  describe "force_https_check" do
    subject(:check) { described_class.new(check_force_https: true).force_https_check }

    it "returns nil if force_https site setting enabled" do
      SiteSetting.force_https = true
      expect(check).to be_nil
    end

    it "returns nil if force_https site setting not enabled" do
      SiteSetting.force_https = false
      expect(check).to eq(I18n.t("dashboard.force_https_warning", base_path: Discourse.base_path))
    end
  end

  describe "ignore force_https_check" do
    subject(:check) { described_class.new(check_force_https: false).force_https_check }

    it "returns nil" do
      SiteSetting.force_https = true
      expect(check).to be_nil

      SiteSetting.force_https = false
      expect(check).to be_nil
    end
  end
  describe "#translation_overrides_check" do
    subject(:dashboard_data) { described_class.new }

    context "when there are outdated translations" do
      before { Fabricate(:translation_override, translation_key: "foo.bar", status: "outdated") }

      it "outputs the correct message" do
        expect(dashboard_data.translation_overrides_check).to eq(
          I18n.t("dashboard.outdated_translations_warning", base_path: Discourse.base_path),
        )
      end
    end

    context "when there are no outdated translations" do
      before { Fabricate(:translation_override, status: "up_to_date") }

      it "outputs nothing" do
        expect(dashboard_data.translation_overrides_check).to eq(nil)
      end
    end
  end
end

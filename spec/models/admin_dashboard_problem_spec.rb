# frozen_string_literal: true

require 'rails_helper'

describe AdminDashboardData do

  describe "adding new checks" do
    after do
      AdminDashboardData.reset_problem_checks
    end

    it 'calls the passed block' do
      called = false
      AdminDashboardData.add_problem_check do
        called = true
      end

      AdminDashboardData.fetch_problems
      expect(called).to eq(true)

      AdminDashboardData.fetch_problems(check_force_https: true)
      expect(called).to eq(true)
    end

    it 'calls the passed method' do
      $test_AdminDashboardData_global = false
      class AdminDashboardData
        def my_test_method
          $test_AdminDashboardData_global = true
        end
      end
      AdminDashboardData.add_problem_check :my_test_method

      AdminDashboardData.fetch_problems
      expect($test_AdminDashboardData_global).to eq(true)
      $test_AdminDashboardData_global = nil
    end
  end

  describe "rails_env_check" do
    subject { described_class.new.rails_env_check }

    it 'returns nil when running in production mode' do
      Rails.stubs(env: ActiveSupport::StringInquirer.new('production'))
      expect(subject).to be_nil
    end

    it 'returns a string when running in development mode' do
      Rails.stubs(env: ActiveSupport::StringInquirer.new('development'))
      expect(subject).to_not be_nil
    end

    it 'returns a string when running in test mode' do
      Rails.stubs(env: ActiveSupport::StringInquirer.new('test'))
      expect(subject).to_not be_nil
    end
  end

  describe 'host_names_check' do
    subject { described_class.new.host_names_check }

    it 'returns nil when host_names is set' do
      Discourse.stubs(:current_hostname).returns('something.com')
      expect(subject).to be_nil
    end

    it 'returns a string when host_name is localhost' do
      Discourse.stubs(:current_hostname).returns('localhost')
      expect(subject).to_not be_nil
    end

    it 'returns a string when host_name is production.localhost' do
      Discourse.stubs(:current_hostname).returns('production.localhost')
      expect(subject).to_not be_nil
    end
  end

  describe 'sidekiq_check' do
    subject { described_class.new.sidekiq_check }

    it 'returns nil when sidekiq processed a job recently' do
      Jobs.stubs(:last_job_performed_at).returns(1.minute.ago)
      Jobs.stubs(:queued).returns(0)
      expect(subject).to be_nil
    end

    it 'returns nil when last job processed was a long time ago, but no jobs are queued' do
      Jobs.stubs(:last_job_performed_at).returns(7.days.ago)
      Jobs.stubs(:queued).returns(0)
      expect(subject).to be_nil
    end

    it 'returns nil when no jobs have ever been processed, but no jobs are queued' do
      Jobs.stubs(:last_job_performed_at).returns(nil)
      Jobs.stubs(:queued).returns(0)
      expect(subject).to be_nil
    end

    it 'returns a string when no jobs were processed recently and some jobs are queued' do
      Jobs.stubs(:last_job_performed_at).returns(20.minutes.ago)
      Jobs.stubs(:queued).returns(1)
      expect(subject).to_not be_nil
    end

    it 'returns a string when no jobs have ever been processed, and some jobs are queued' do
      Jobs.stubs(:last_job_performed_at).returns(nil)
      Jobs.stubs(:queued).returns(1)
      expect(subject).to_not be_nil
    end
  end

  describe 'ram_check' do
    subject { described_class.new.ram_check }

    it 'returns nil when total ram is 1 GB' do
      MemInfo.any_instance.stubs(:mem_total).returns(1025272)
      expect(subject).to be_nil
    end

    it 'returns nil when total ram cannot be determined' do
      MemInfo.any_instance.stubs(:mem_total).returns(nil)
      expect(subject).to be_nil
    end

    it 'returns a string when total ram is less than 1 GB' do
      MemInfo.any_instance.stubs(:mem_total).returns(512636)
      expect(subject).to_not be_nil
    end
  end

  describe 'auth_config_checks' do

    shared_examples 'problem detection for login providers' do
      context 'when disabled' do
        it 'returns nil' do
          SiteSetting.set(enable_setting, false)
          expect(subject).to be_nil
        end
      end

      context 'when enabled' do
        before do
          SiteSetting.set(enable_setting, true)
        end

        it 'returns nil when key and secret are set' do
          SiteSetting.set(key, '12313213')
          SiteSetting.set(secret, '12312313123')
          expect(subject).to be_nil
        end

        it 'returns a string when key is not set' do
          SiteSetting.set(key, '')
          SiteSetting.set(secret, '12312313123')
          expect(subject).to_not be_nil
        end

        it 'returns a string when secret is not set' do
          SiteSetting.set(key, '123123')
          SiteSetting.set(secret, '')
          expect(subject).to_not be_nil
        end

        it 'returns a string when key and secret are not set' do
          SiteSetting.set(key, '')
          SiteSetting.set(secret, '')
          expect(subject).to_not be_nil
        end
      end
    end

    describe 'facebook' do
      subject { described_class.new.facebook_config_check }
      let(:enable_setting) { :enable_facebook_logins }
      let(:key) { :facebook_app_id }
      let(:secret) { :facebook_app_secret }
      include_examples 'problem detection for login providers'
    end

    describe 'twitter' do
      subject { described_class.new.twitter_config_check }
      let(:enable_setting) { :enable_twitter_logins }
      let(:key) { :twitter_consumer_key }
      let(:secret) { :twitter_consumer_secret }
      include_examples 'problem detection for login providers'
    end

    describe 'github' do
      subject { described_class.new.github_config_check }
      let(:enable_setting) { :enable_github_logins }
      let(:key) { :github_client_id }
      let(:secret) { :github_client_secret }
      include_examples 'problem detection for login providers'
    end
  end

  describe 's3_config_check' do
    shared_examples 'problem detection for s3-dependent setting' do
      subject { described_class.new.s3_config_check }
      let(:access_keys) { [:s3_access_key_id, :s3_secret_access_key] }
      let(:all_cred_keys) { access_keys + [:s3_use_iam_profile] }
      let(:all_setting_keys) { all_cred_keys + [bucket_key] }

      def all_setting_permutations(keys)
        ['a', ''].repeated_permutation(keys.size) do |*values|
          hash = Hash[keys.zip(values)]
          hash.each do |key, value|
            SiteSetting.set(key, value)
          end
          yield hash
        end
      end

      context 'when setting is enabled' do
        before do
          all_setting_keys.each { |key| SiteSetting.set(key, 'foo') }
          SiteSetting.set(setting[:key], setting[:enabled_value])
          SiteSetting.set(bucket_key, bucket_value)
        end

        context 'when bucket is blank' do
          let(:bucket_value) { '' }

          it "always returns a string" do
            all_setting_permutations(all_cred_keys) do
              expect(subject).to_not be_nil
            end
          end
        end

        context 'when bucket is filled in' do
          let(:bucket_value) { 'a' }
          before do
            SiteSetting.s3_use_iam_profile = use_iam_profile
          end

          context 'when using iam profile' do
            let(:use_iam_profile) { true }

            it 'always returns nil' do
              all_setting_permutations(access_keys) do
                expect(subject).to be_nil
              end
            end
          end

          context 'when not using iam profile' do
            let(:use_iam_profile) { false }

            it 'returns nil only if both access key fields are filled in' do
              all_setting_permutations(access_keys) do |settings|
                if settings.values.all?
                  expect(subject).to be_nil
                else
                  expect(subject).to_not be_nil
                end
              end
            end
          end
        end
      end

      context 'when setting is not enabled' do
        before do
          SiteSetting.set(setting[:key], setting[:disabled_value])
        end

        it "always returns nil" do
          all_setting_permutations(all_setting_keys) do
            expect(subject).to be_nil
          end
        end
      end
    end

    describe 'uploads' do
      let(:setting) do
        {
          key: :enable_s3_uploads,
          enabled_value: true,
          disabled_value: false
        }
      end
      let(:bucket_key) { :s3_upload_bucket }
      include_examples 'problem detection for s3-dependent setting'
    end

    describe 'backups' do
      let(:setting) do
        {
          key: :backup_location,
          enabled_value: BackupLocationSiteSetting::S3,
          disabled_value: BackupLocationSiteSetting::LOCAL
        }
      end
      let(:bucket_key) { :s3_backup_bucket }
      include_examples 'problem detection for s3-dependent setting'
    end
  end

  describe 'force_https_check' do
    subject { described_class.new(check_force_https: true).force_https_check }

    it 'returns nil if force_https site setting enabled' do
      SiteSetting.force_https = true
      expect(subject).to be_nil
    end

    it 'returns nil if force_https site setting not enabled' do
      SiteSetting.force_https = false
      expect(subject).to eq(I18n.t('dashboard.force_https_warning', base_path: Discourse.base_path))
    end
  end

  describe 'ignore force_https_check' do
    subject { described_class.new(check_force_https: false).force_https_check }

    it 'returns nil' do
      SiteSetting.force_https = true
      expect(subject).to be_nil

      SiteSetting.force_https = false
      expect(subject).to be_nil
    end
  end

  describe 'stats cache' do
    include_examples 'stats cachable'
  end

  describe '#problem_message_check' do
    let(:key) { AdminDashboardData.problem_messages.first }

    before do
      described_class.clear_problem_message(key)
    end

    it 'returns nil if message has not been added' do
      expect(described_class.problem_message_check(key)).to be_nil
    end

    it 'returns a message if it was added' do
      described_class.add_problem_message(key)
      expect(described_class.problem_message_check(key)).to eq(I18n.t(key, base_path: Discourse.base_path))
    end

    it 'returns a message if it was added with an expiry' do
      described_class.add_problem_message(key, 300)
      expect(described_class.problem_message_check(key)).to eq(I18n.t(key, base_path: Discourse.base_path))
    end
  end

  describe '#out_of_date_themes' do
    let(:remote) { RemoteTheme.create!(remote_url: "https://github.com/org/testtheme") }
    let!(:theme) { Fabricate(:theme, remote_theme: remote, name: "Test< Theme") }

    it "outputs correctly formatted html" do
      remote.update!(local_version: "old version", remote_version: "new version", commits_behind: 2)
      dashboard_data = described_class.new
      expect(dashboard_data.out_of_date_themes).to eq(
        I18n.t("dashboard.out_of_date_themes") + "<ul><li><a href=\"/admin/customize/themes/#{theme.id}\">Test&lt; Theme</a></li></ul>"
      )

      remote.update!(local_version: "new version", commits_behind: 0)
      expect(dashboard_data.out_of_date_themes).to eq(nil)
    end
  end

  describe '#unreachable_themes' do
    let(:remote) { RemoteTheme.create!(remote_url: "https://github.com/org/testtheme", last_error_text: "can't reach repo :'(") }
    let!(:theme) { Fabricate(:theme, remote_theme: remote, name: "Test< Theme") }

    it "outputs correctly formatted html" do
      dashboard_data = described_class.new
      expect(dashboard_data.unreachable_themes).to eq(
        I18n.t("dashboard.unreachable_themes") + "<ul><li><a href=\"/admin/customize/themes/#{theme.id}\">Test&lt; Theme</a></li></ul>"
      )

      remote.update!(last_error_text: nil)
      expect(dashboard_data.out_of_date_themes).to eq(nil)
    end
  end
end

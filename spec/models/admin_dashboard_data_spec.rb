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

  describe 'send_consumer_email_check' do
    subject { described_class.new.send_consumer_email_check }

    it 'returns nil if gmail.com is not in the smtp_settings address' do
      ActionMailer::Base.stubs(:smtp_settings).returns({address: 'mandrillapp.com'})
      expect(subject).to be_nil
    end

    context 'gmail.com is in the smtp_settings address' do
      before { ActionMailer::Base.stubs(:smtp_settings).returns({address: 'smtp.gmail.com'}) }

      it 'returns nil in development env' do
        Rails.stubs(env: ActiveSupport::StringInquirer.new('development'))
        expect(subject).to be_nil
      end

      it 'returns a string when in production env' do
        Rails.stubs(env: ActiveSupport::StringInquirer.new('production'))
        expect(subject).not_to be_nil
      end
    end
  end

  describe 'default_logo_check' do
    subject { described_class.new.default_logo_check }

    describe 'favicon_url check' do
      before do
        SiteSetting.logo_url = '/assets/my-logo.jpg'
        SiteSetting.logo_small_url = '/assets/my-small-logo.jpg'
      end

      it 'returns a string when favicon_url is default' do
        expect(subject).not_to be_nil
      end

      it 'returns a string when favicon_url contains default filename' do
        SiteSetting.favicon_url = "/prefix#{SiteSetting.defaults[:favicon_url]}"
        expect(subject).not_to be_nil
      end

      it 'returns nil when favicon_url does not match default-favicon.png' do
        SiteSetting.favicon_url = '/assets/my-favicon.png'
        expect(subject).to be_nil
      end
    end

    describe 'logo_url check' do
      before do
        SiteSetting.favicon_url = '/assets/my-favicon.png'
        SiteSetting.logo_small_url = '/assets/my-small-logo.jpg'
      end

      it 'returns a string when logo_url is default' do
        expect(subject).not_to be_nil
      end

      it 'returns a string when logo_url contains default filename' do
        SiteSetting.logo_url = "/prefix#{SiteSetting.defaults[:logo_url]}"
        expect(subject).not_to be_nil
      end

      it 'returns nil when logo_url does not match d-logo-sketch.png' do
        SiteSetting.logo_url = '/assets/my-logo.png'
        expect(subject).to be_nil
      end
    end

    # etc.
  end

  describe 'auth_config_checks' do

    shared_examples 'problem detection for login providers' do
      context 'when disabled' do
        it 'returns nil' do
          SiteSetting.stubs(enable_setting).returns(false)
          expect(subject).to be_nil
        end
      end

      context 'when enabled' do
        before do
          SiteSetting.stubs(enable_setting).returns(true)
        end

        it 'returns nil key and secret are set' do
          SiteSetting.stubs(key).returns('12313213')
          SiteSetting.stubs(secret).returns('12312313123')
          expect(subject).to be_nil
        end

        it 'returns a string when key is not set' do
          SiteSetting.stubs(key).returns('')
          SiteSetting.stubs(secret).returns('12312313123')
          expect(subject).to_not be_nil
        end

        it 'returns a string when secret is not set' do
          SiteSetting.stubs(key).returns('123123')
          SiteSetting.stubs(secret).returns('')
          expect(subject).to_not be_nil
        end

        it 'returns a string when key and secret are not set' do
          SiteSetting.stubs(key).returns('')
          SiteSetting.stubs(secret).returns('')
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
      expect(described_class.problem_message_check(key)).to eq(I18n.t(key))
    end

    it 'returns a message if it was added with an expiry' do
      described_class.add_problem_message(key, 300)
      expect(described_class.problem_message_check(key)).to eq(I18n.t(key))
    end
  end

end

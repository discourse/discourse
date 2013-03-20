require 'spec_helper'

describe AdminDashboardData do

  describe "rails_env_check" do
    subject { AdminDashboardData.new.rails_env_check }

    it 'returns nil when running in production mode' do
      Rails.stubs(:env).returns('production')
      subject.should be_nil
    end

    it 'returns a string when running in development mode' do
      Rails.stubs(:env).returns('development')
      subject.should_not be_nil
    end

    it 'returns a string when running in test mode' do
      Rails.stubs(:env).returns('test')
      subject.should_not be_nil
    end
  end

  describe 'host_names_check' do
    subject { AdminDashboardData.new.host_names_check }

    it 'returns nil when host_names is set' do
      Discourse.stubs(:current_hostname).returns('something.com')
      subject.should be_nil
    end

    it 'returns a string when host_name is localhost' do
      Discourse.stubs(:current_hostname).returns('localhost')
      subject.should_not be_nil
    end

    it 'returns a string when host_name is production.localhost' do
      Discourse.stubs(:current_hostname).returns('production.localhost')
      subject.should_not be_nil
    end
  end

  describe 'gc_checks' do
    subject { AdminDashboardData.new.gc_checks }

    it 'returns nil when gc params are set' do
      ENV.stubs(:[]).with('RUBY_GC_MALLOC_LIMIT').returns(90000000)
      subject.should be_nil
    end

    it 'returns a string when gc params are not set' do
      ENV.stubs(:[]).with('RUBY_GC_MALLOC_LIMIT').returns(nil)
      subject.should_not be_nil
    end
  end

end
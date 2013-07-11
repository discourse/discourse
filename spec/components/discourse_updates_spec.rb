require 'spec_helper'
require_dependency 'discourse_updates'

describe DiscourseUpdates do

  def stub_data(latest, missing, critical, updated_at)
    DiscourseUpdates.stubs(:latest_version).returns(latest)
    DiscourseUpdates.stubs(:missing_versions_count).returns(missing)
    DiscourseUpdates.stubs(:critical_updates_available?).returns(critical)
    DiscourseUpdates.stubs(:updated_at).returns(updated_at)
  end

  before do
    Jobs::VersionCheck.any_instance.stubs(:execute).returns(true)
  end

  subject { DiscourseUpdates.check_version.as_json }

  context 'a good version check request happened recently' do
    context 'and server is up-to-date' do
      before { stub_data(Discourse::VERSION::STRING, 0, false, 12.hours.ago) }

      it 'returns all the version fields' do
        subject['latest_version'].should == Discourse::VERSION::STRING
        subject['missing_versions_count'].should == 0
        subject['critical_updates'].should == false
        subject['installed_version'].should == Discourse::VERSION::STRING
      end

      it 'returns the timestamp of the last version check' do
        subject['updated_at'].should be_within_one_second_of(12.hours.ago)
      end
    end

    context 'and server is not up-to-date' do
      before { stub_data('0.9.0', 2, false, 12.hours.ago) }

      it 'returns all the version fields' do
        subject['latest_version'].should == '0.9.0'
        subject['missing_versions_count'].should == 2
        subject['critical_updates'].should == false
        subject['installed_version'].should == Discourse::VERSION::STRING
      end

      it 'returns the timestamp of the last version check' do
        subject['updated_at'].should be_within_one_second_of(12.hours.ago)
      end
    end
  end

  context 'a version check has never been performed' do
    before { stub_data(nil, nil, false, nil) }

    it 'returns the installed version' do
      subject['installed_version'].should == Discourse::VERSION::STRING
    end

    it 'indicates that version check has not been performed' do
      subject.should have_key('updated_at')
      subject['updated_at'].should == nil
    end

    it 'does not return latest version info' do
      subject.should_not have_key('latest_version')
      subject.should_not have_key('missing_versions_count')
      subject.should_not have_key('critical_updates')
    end

    it 'queues a version check' do
      Jobs.expects(:enqueue).with(:version_check, anything)
      subject
    end
  end

  context 'installed version is newer' do
    before { stub_data('0.9.3', 0, false, 28.hours.ago) }

    it 'queues a version check' do
      Jobs.expects(:enqueue).with(:version_check, anything)
      subject
    end
  end

end

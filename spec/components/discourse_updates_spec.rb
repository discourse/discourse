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

  context 'version check was done at the current installed version' do
    before do
      DiscourseUpdates.stubs(:last_installed_version).returns(Discourse::VERSION::STRING)
    end

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

    # These cases should never happen anymore, but keep the specs to be sure
    # they're handled in a sane way.
    context 'old version check data' do
      shared_examples "queue version check and report that version is ok" do
        it 'queues a version check' do
          Jobs.expects(:enqueue).with(:version_check, anything)
          subject
        end

        it 'reports 0 missing versions' do
          subject['missing_versions_count'].should == 0
        end

        it 'reports that a version check will be run soon' do
          subject['version_check_pending'].should == true
        end
      end

      context 'installed is latest' do
        before { stub_data(Discourse::VERSION::STRING, 1, false, 8.hours.ago) }
        include_examples "queue version check and report that version is ok"
      end

      context 'installed does not match latest version, but missing_versions_count is 0' do
        before { stub_data('0.10.10.123', 0, false, 8.hours.ago) }
        include_examples "queue version check and report that version is ok"
      end
    end
  end

  context 'version check was done at a different installed version' do
    before do
      DiscourseUpdates.stubs(:last_installed_version).returns('0.9.1')
    end

    shared_examples "when last_installed_version is old" do
      it 'queues a version check' do
        Jobs.expects(:enqueue).with(:version_check, anything)
        subject
      end

      it 'reports 0 missing versions' do
        subject['missing_versions_count'].should == 0
      end

      it 'reports that a version check will be run soon' do
        subject['version_check_pending'].should == true
      end
    end

    context 'missing_versions_count is 0' do
      before { stub_data('0.9.7', 0, false, 8.hours.ago) }
      include_examples "when last_installed_version is old"
    end

    context 'missing_versions_count is not 0' do
      before { stub_data('0.9.7', 1, false, 8.hours.ago) }
      include_examples "when last_installed_version is old"
    end
  end
end

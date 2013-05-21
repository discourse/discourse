require 'spec_helper'
require 'jobs'

describe Jobs::ClockworkHeartbeat do

  describe '#is_clockwork_running?' do

    subject { Jobs::ClockworkHeartbeat.is_clockwork_running? }

    it 'returns false if last_heartbeat_at is nil' do
      Jobs::ClockworkHeartbeat.any_instance.stubs(:last_heartbeat_at).returns(nil)
      subject.should be_false
    end

    it 'returns false if last_heartbeat_at is more than 2 minutes ago' do
      Jobs::ClockworkHeartbeat.any_instance.stubs(:last_heartbeat_at).returns(10.minutes.ago)
      subject.should be_false
    end

    it 'returns true if last_heartbeat_at is more recent than 2 minutes ago' do
      Jobs::ClockworkHeartbeat.any_instance.stubs(:last_heartbeat_at).returns(Time.zone.now)
      subject.should be_true
    end
  end

end
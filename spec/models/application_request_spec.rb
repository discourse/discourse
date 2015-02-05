require 'spec_helper'

describe ApplicationRequest do

  before do
    ApplicationRequest.clear_cache!
  end

  def inc(key,opts=nil)
    ApplicationRequest.increment!(key,opts)
  end

  it 'logs nothing for an unflushed increment' do
    ApplicationRequest.increment!(:anon)
    ApplicationRequest.count.should == 0
  end

  it 'can automatically flush' do
    t1 = Time.now.utc.at_midnight
    freeze_time(t1)
    inc(:total)
    inc(:total)
    inc(:total, autoflush: 3)

    ApplicationRequest.first.count.should == 3
  end

  it 'flushes yesterdays results' do
    t1 = Time.now.utc.at_midnight
    freeze_time(t1)
    inc(:total)
    freeze_time(t1.tomorrow)
    inc(:total)

    ApplicationRequest.write_cache!
    ApplicationRequest.count.should == 2
  end

  it 'clears cache correctly' do
    # otherwise we have test pollution
    inc(:anon)
    ApplicationRequest.clear_cache!
    ApplicationRequest.write_cache!

    ApplicationRequest.count.should == 0
  end

  it 'logs a few counts once flushed' do
    time = Time.now.at_midnight
    freeze_time(time)

    3.times { inc(:total) }
    2.times { inc(:success) }
    4.times { inc(:redirect) }

    ApplicationRequest.write_cache!

    ApplicationRequest.total.first.count.should == 3
    ApplicationRequest.success.first.count.should == 2
    ApplicationRequest.redirect.first.count.should == 4

  end
end

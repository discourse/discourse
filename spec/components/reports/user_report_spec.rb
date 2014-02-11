require 'spec_helper'
require_dependency 'reports/user_report'

describe UserReport do
  it 'only accepts valid date ranges' do
    expect { UserReport.new(nil, nil).to raise_error } # nil is bad
    expect { UserReport.new(Time.now, 30.days.ago).to raise_error } # range reversed
    expect { UserReport.new(30.days.ago, Time.now).not_to raise_error }
  end
  it 'generates valid csv data' do
    time = 1.day.ago
    user = Fabricate(:user, username: 'bruce0', email: 'bruce0@wayne.com', last_seen_at: time)
    topic = Fabricate(:topic, user: user)
    post = Fabricate(:post, topic: topic, user: user)
    user_report.send(:build_csv).should == "Username,Email,Last seen at,Topics created,Topics entered,Posts created\nbruce0,bruce0@wayne.com,#{time},1,0,1\n"
  end
  it 'has a filename without spaces' do
    user_report.file_name.should_not =~ / /
  end
  
private
  
  def user_report
    UserReport.new(30.days.ago, Time.now)
  end
end

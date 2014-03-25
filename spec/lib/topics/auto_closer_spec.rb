require 'spec_helper'
require 'topics/auto_closer'

describe Topics::AutoCloser do
  let(:frozen_time) { Time.zone.local(2013, 11, 26, 17, 0, 0)}

  describe "JSON format" do
    let(:closer) { Topics::AutoCloser.get_closer_method("2013-11-26T21:00:00.000Z") }

    it "must update the topic auto close at to the json date" do
      Timecop.travel(frozen_time) do
        closer.call(topic = Topic.new)
        topic.auto_close_at.should == "Tue, 26 Nov 2013 16:00:00 EST -05:00:Time"
      end
    end
  end

  describe "hour string format" do
    let(:closer) { Topics::AutoCloser.get_closer_method("12:00") }

    it "must update the topic auto close at to 12 the next day" do
      Timecop.travel(frozen_time) do
        closer.call(topic = Topic.new)
        topic.auto_close_at.should == "Wed, 27 Nov 2013 12:00:00 EST -05:00"
      end
    end
  end

  describe "a timestamp format" do
    let(:closer) { Topics::AutoCloser.get_closer_method("2013-11-25 13:00") }

    it "must update the topic auto close at to the timestamp" do
      Timecop.travel(frozen_time) do
        closer.call(topic = Topic.new)
        topic.auto_close_at.should == "Mon, 25 Nov 2013 13:00:00 EST -05:00"
      end
    end
  end

  describe "a nil" do
    let(:closer) { Topics::AutoCloser.get_closer_method(nil) }

    it "must set the auto close to nil" do
      Timecop.travel(frozen_time) do
        closer.call(topic = Topic.new)
        topic.auto_close_at.should == nil
      end
    end
  end

end

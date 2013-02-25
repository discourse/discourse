require 'spec_helper'
describe ErrorLog do

  def boom
    raise "boom"
  end

  def exception
    begin
      boom
    rescue => e
      return e
    end
  end

  def controller
    DraftController.new
  end

  def request
    ActionController::TestRequest.new(:host => 'test')
  end

  describe "add_row!" do
    it "creates a non empty file on first call" do
      ErrorLog.clear_all!
      ErrorLog.add_row!(hello: "world")
      File.exists?(ErrorLog.filename).should be_true
    end
  end

  describe "logging data" do
    it "is able to read the data it writes" do
      ErrorLog.clear_all!
      ErrorLog.report!(exception, controller, request, nil)
      ErrorLog.report!(exception, controller, request, nil)
      i = 0
      ErrorLog.each do |h|
        i += 1
      end
      i.should == 2
    end

    it "is able to skip rows" do
      ErrorLog.clear_all!
      ErrorLog.report!(exception, controller, request, nil)
      ErrorLog.report!(exception, controller, request, nil)
      ErrorLog.report!(exception, controller, request, nil)
      ErrorLog.report!(exception, controller, request, nil)
      i = 0
      ErrorLog.skip(3) do |h|
        i += 1
      end
      i.should == 1
    end
  end

end

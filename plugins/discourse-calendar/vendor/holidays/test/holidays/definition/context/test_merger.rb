require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/context/merger'

class MergerTests < Test::Unit::TestCase
  def setup
    @target_regions = [:new_region]
    @target_holidays = {0 => [:mday => 1, :name => "Test", :regions => [:test2, :test]]}
    @target_custom_methods = {"test_method" => Proc.new { |year| Date.civil(year, 1, 1) } }

    @holidays_repo = mock()
    @regions_repo = mock()
    @custom_methods_repo = mock()

    @subject = Holidays::Definition::Context::Merger.new(@holidays_repo, @regions_repo, @custom_methods_repo)
  end

  def test_repos_are_called_to_add_regions_and_holidays
    @holidays_repo.expects(:add).with(@target_holidays)
    @regions_repo.expects(:add).with(@target_regions)
    @custom_methods_repo.expects(:add).with(@target_custom_methods)

    @subject.call(@target_regions, @target_holidays, @target_custom_methods)
  end
end

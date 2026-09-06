require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/context/load'

class LoadTests < Test::Unit::TestCase
  def setup
    @definition_merger = mock()
    full_definitions_path = File.expand_path(File.dirname(__FILE__)) + '/../../../data'

    @subject = Holidays::Definition::Context::Load.new(
      @definition_merger,
      full_definitions_path,
    )
  end

  def test_region_is_found_and_loaded_and_merged
    @definition_merger.expects(:call).with(:test_region, {}, {})
    @subject.call(:test_region)
  end

  def test_region_file_not_found
    assert_raises Holidays::UnknownRegionError do
      @subject.call(:unknown)
    end
  end

  def test_region_can_be_loaded_but_file_is_invalid
    assert_raises Holidays::UnknownRegionError do
      @subject.call(:test_invalid_region)
    end
  end

  def test_returns_list_of_loaded_regions
    @definition_merger.expects(:call).with(:test_region, {}, {})
    assert_equal([:test_region, :test_region2], @subject.call(:test_region), "Should cache subregions under the parent region's name")
  end
end

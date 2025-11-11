require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

class AllRegionsTests < Test::Unit::TestCase
  def setup
    Holidays::LoadAllDefinitions.call
  end

  def test_definition_dir
    assert File.directory?(Holidays::FULL_DEFINITIONS_PATH)
  end

  def test_show_available_regions
    regions = Holidays.available_regions

    assert_equal regions.size, Holidays::REGIONS.size
    assert_equal regions, Holidays::REGIONS
  end

  def test_load_subregion
    holidays = Holidays.on(Date.civil(2014, 1, 1), :de_bb)
    assert holidays.any? { |h| h[:name] == 'Neujahrstag' }

    holidays = Holidays.on(Date.civil(2020, 1, 1), :de_bb)
    assert holidays.any? { |h| h[:name] == 'Neujahrstag' }

    holidays = Holidays.on(Date.civil(2027, 1, 1), :de_bb)
    assert holidays.any? { |h| h[:name] == 'Neujahrstag' }
  end

  def test_unknown_region_raises_exception
    assert_raise Holidays::InvalidRegion do
      Holidays.on(Date.civil(2014, 1, 1), :something_we_do_not_recognize)
    end

    assert_raise Holidays::InvalidRegion do
      Holidays.on(Date.civil(2020, 1, 1), :something_we_do_not_recognize)
    end

    assert_raise Holidays::InvalidRegion do
      Holidays.on(Date.civil(2030, 1, 1), :something_we_do_not_recognize)
    end
  end

  def test_malicious_load_attempt_raises_exception
    assert_raise Holidays::InvalidRegion do
      Holidays.between(Date.civil(2014, 1, 1), Date.civil(2016, 1, 1), '../../../../../../../../../../../../tmp/profile_pic.jpg')
    end
  end
end

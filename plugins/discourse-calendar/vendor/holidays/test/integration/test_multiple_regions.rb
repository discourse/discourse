require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'
require "#{Holidays::DEFINITIONS_PATH}/gb"
require "#{Holidays::DEFINITIONS_PATH}/ie"

class MultipleRegionsTests < Test::Unit::TestCase
  # Simulate load of new environment where the repositories begin empty
  def reset_cache
    Holidays::Factory::Definition.instance_variable_set(:@regions_repo, nil)
    Holidays::Factory::Definition.instance_variable_set(:@holidays_repo, nil)
  end

  def test_defining_holidays
    h = Holidays.on(Date.new(2008, 12, 26), :ie)
    assert_equal 'St. Stephen\'s Day', h[0][:name]

    h = Holidays.on(Date.new(2008, 5, 9), :gb_)
    assert_equal 'Liberation Day', (h[0] || {})[:name]

    h = Holidays.on(Date.new(2008, 5, 9), :je)
    assert_equal 'Liberation Day', h[0][:name]

    h = Holidays.on(Date.new(2008, 5, 9), :gb)
    assert h.empty?
  end

  def test_north_american_parent_region_lookup
    assert_equal :ca, Holidays::PARENT_REGION_LOOKUP[:ca]
    assert_equal :ca, Holidays::PARENT_REGION_LOOKUP[:ca_qc]
    assert_equal :mx, Holidays::PARENT_REGION_LOOKUP[:mx]
    assert_equal :mx, Holidays::PARENT_REGION_LOOKUP[:mx_pue]
    assert_equal :us, Holidays::PARENT_REGION_LOOKUP[:us]
    assert_equal :us, Holidays::PARENT_REGION_LOOKUP[:us_fl]
  end

  def test_north_american_subregion_caching
    { ca: :ca_qc, mx: :mx_pue, us: :us_fl }.each do |region, subregion|
      module_name = region.upcase

      reset_cache
      Holidays.on(Date.new(2018, 1, 1), region)  # Test check on regional holidays
      assert_equal [region], Holidays::Factory::Definition.regions_repository.all_loaded, "Only Holidays::#{module_name} should be loaded"
      holiday_regions = Holidays::Factory::Definition.holidays_by_month_repository.all.values.flatten.map { |h| h[:regions] }.uniq.flatten
      assert_includes holiday_regions, region, 'Region holidays should be loaded'
      assert_includes holiday_regions, subregion, 'Subregion holidays should be loaded'

      reset_cache
      Holidays.on(Date.new(2018, 1, 1), subregion)  # Test check on subregional holidays
      assert_equal [region], Holidays::Factory::Definition.regions_repository.all_loaded, "Only Holidays::#{module_name} should be loaded"
      holiday_regions = Holidays::Factory::Definition.holidays_by_month_repository.all.values.flatten.map { |h| h[:regions] }.uniq.flatten
      assert_includes holiday_regions, region, 'Region holidays should be loaded'
      assert_includes holiday_regions, subregion, 'Subregion holidays should be loaded'
    end
  end

  def test_north_american_cross_region_caching
    reset_cache
    Holidays.on(Date.new(2018, 1, 1), :us)
    assert_equal [:us], Holidays::Factory::Definition.regions_repository.all_loaded, 'Only Holidays::US should be loaded'
    holiday_regions = Holidays::Factory::Definition.holidays_by_month_repository.all.values.flatten.map { |h| h[:regions] }.uniq.flatten
    assert_includes holiday_regions, :us, 'Region holidays should be loaded'
    assert_includes holiday_regions, :us_fl, 'Subregion holidays should be loaded'

    Holidays.on(Date.new(2018, 1, 1), :ca)
    assert_equal [:us, :ca], Holidays::Factory::Definition.regions_repository.all_loaded, 'Only Holidays::US and Holidays::CA should be loaded'
    holiday_regions = Holidays::Factory::Definition.holidays_by_month_repository.all.values.flatten.map { |h| h[:regions] }.uniq.flatten
    assert_includes holiday_regions, :us, 'Region holidays should be loaded'
    assert_includes holiday_regions, :ca, 'Region holidays should be loaded'
    assert_includes holiday_regions, :us_fl, 'Subregion holidays should be loaded'
    assert_includes holiday_regions, :ca_qc, 'Subregion holidays should be loaded'
  end
end

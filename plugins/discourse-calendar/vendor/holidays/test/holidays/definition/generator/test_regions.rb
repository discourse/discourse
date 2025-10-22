require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/generator/regions'

class GeneratorRegionsTests < Test::Unit::TestCase
  def setup
    @generator = Holidays::Definition::Generator::Regions.new
  end

  def test_generates_regions_single_region_multiple_subregions
    regions = {:region1 => [:test, :test2]}
    expected = <<-EOE
# encoding: utf-8
module Holidays
  REGIONS = [:test, :test2]

  PARENT_REGION_LOOKUP = {:test=>:region1, :test2=>:region1}
end
EOE

    assert_equal expected, @generator.call(regions)
  end

  def test_generates_regions_multiple_regions_single_unique_subregions
    regions = {:region1 => [:test], :region2 => [:test2]}
    expected = <<-EOE
# encoding: utf-8
module Holidays
  REGIONS = [:test, :test2]

  PARENT_REGION_LOOKUP = {:test=>:region1, :test2=>:region2}
end
EOE

    assert_equal expected, @generator.call(regions)
  end

  def test_generates_regions_multiple_regions_multiple_overlapping_subregions
    regions = {:region1 => [:test], :region2 => [:test, :test2], :region3 => [:test3, :test]}
    expected = <<-EOE
# encoding: utf-8
module Holidays
  REGIONS = [:test, :test2, :test3]

  PARENT_REGION_LOOKUP = {:test=>:region1, :test2=>:region2, :test3=>:region3}
end
EOE

    assert_equal expected, @generator.call(regions)
  end

  def test_generates_regions_multiple_regions_multiple_overlapping_subregions_complex
    regions = {
      :region1 => [:test],
      :region2 => [:test, :test2],
      :region3 => [:test3, :test],
      :region4 => [:test4, :test2],
      :region5 => [:test4, :test5, :test3],
      :region6 => [:test4, :test6, :test],
    }

    expected = <<-EOE
# encoding: utf-8
module Holidays
  REGIONS = [:test, :test2, :test3, :test4, :test5, :test6]

  PARENT_REGION_LOOKUP = {:test=>:region1, :test2=>:region2, :test3=>:region3, :test4=>:region4, :test5=>:region5, :test6=>:region6}
end
EOE

    assert_equal expected, @generator.call(regions)
  end

  def test_returns_error_if_regions_is_empty
    regions = {}

    assert_raises ArgumentError do
      @generator.call(regions)
    end
  end

  def test_returns_error_if_regions_is_not_a_hash
    regions = "invalid"

    assert_raises ArgumentError do
      @generator.call(regions)
    end
  end

  def test_returns_error_if_regions_is_nil
    regions = nil

    assert_raises ArgumentError do
      @generator.call(regions)
    end
  end
end

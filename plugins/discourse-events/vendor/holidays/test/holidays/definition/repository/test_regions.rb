require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/repository/regions'

class RegionsRepoTests < Test::Unit::TestCase
  def setup
    @all_generated_regions = [:parent, :subregion, :subregion_with_underscores, :region1, :region2]
    @parent_region_lookup = {
      :subregion => :parent,
      :subregion_with_underscores => :parent,
    }

    @subject = Holidays::Definition::Repository::Regions.new(@all_generated_regions, @parent_region_lookup)
  end

  def test_all_loaded_returns_an_empty_array_if_just_initialize
    assert_equal([], @subject.all_loaded)
  end

  def test_add_successfully_adds_a_region
    @subject.add(:test)
    assert_equal([:test], @subject.all_loaded)
  end

  def test_add_raises_error_if_symbol_not_provided
    assert_raises ArgumentError do
      @subject.add('not-a-symbol')
    end
  end

  def test_add_raises_error_if_argument_is_nil
    assert_raises ArgumentError do
      @subject.add(nil)
    end
  end

  def test_add_raises_error_if_any_region_is_not_a_symbol
    assert_raises ArgumentError do
      @subject.add([:test, 'not-a-symbol'])
    end
  end

  def test_add_does_not_add_if_the_region_already_exists
    @subject.add(:test)
    @subject.add(:test)
    assert_equal([:test], @subject.all_loaded)
  end

  def test_add_accepts_array_of_regions
    @subject.add([:test, :test2])
    assert_equal([:test, :test2], @subject.all_loaded)
  end

  def test_exists_returns_true_if_region_is_present
    @subject.add(:test)
    assert @subject.loaded?(:test)
  end

  def tests_exists_returns_false_if_region_is_not_present
    assert_equal(false, @subject.loaded?(:something))
  end

  def test_exists_raises_error_if_invalid_argument
    assert_raises ArgumentError do
      @subject.loaded?(nil)
    end
  end

  def test_search_returns_empty_array_if_no_matches_found
    assert_equal([], @subject.search(:something))
  end

  def test_search_returns_matches_on_prefix
    @subject.add([:another_region, :test_region])
    assert_equal([:test_region], @subject.search(:test_))
  end

  def test_search_returns_multiple_matches_on_prefix
    @subject.add([:another_region, :test_region, :test_region2])
    assert_equal([:test_region, :test_region2], @subject.search(:test_))
  end

  def test_search_raises_error_if_prefix_is_not_a_string
    assert_raises ArgumentError do
      @subject.search("string")
    end

    assert_raises ArgumentError do
      @subject.search(nil)
    end
  end

  def test_all_generated_returns_value_from_initializer
    assert_equal(@all_generated_regions, @subject.all_generated)
  end

  def test_parent_region_lookup_returns_region_if_it_exists
    assert_equal(@parent_region_lookup[:subregion], @subject.parent_region_lookup(:subregion))
  end

  def test_parent_region_lookup_returns_nil_if_does_not_exist_in_lookup
    assert_nil(@subject.parent_region_lookup(:parent))
  end
end

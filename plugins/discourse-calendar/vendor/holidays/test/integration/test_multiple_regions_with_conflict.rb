require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

# See https://github.com/holidays/holidays/issues/344 for more info on why
# these tests exist.
class MultipleRegionsWithConflictsTests < Test::Unit::TestCase

  def test_corpus_christi_returns_correctly_for_co_even_if_br_is_loaded_first
    result = Holidays.on(Date.new(2014, 6, 19), :br)
    assert_equal 1, result.count
    assert_equal 'Corpus Christi', result.first[:name]

    result = Holidays.on(Date.new(2014, 6, 23), :co)
    assert_equal 1, result.count
    assert_equal 'Corpus Christi', result.first[:name]
  end

  def test_custom_loaded_region_returns_correct_value_with_function_modifier_conflict_even_if_conflict_definition_is_loaded_first
    Holidays.load_custom('test/data/test_multiple_regions_with_conflicts_region_1.yaml')
    result = Holidays.on(Date.new(2019, 6, 20), :multiple_with_conflict_1)
    assert_equal 1, result.count
    assert_equal 'With Function Modifier', result.first[:name]

    Holidays.load_custom('test/data/test_multiple_regions_with_conflicts_region_2.yaml')
    result = Holidays.on(Date.new(2019, 6, 24), :multiple_with_conflict_2)
    assert_equal 1, result.count
    assert_equal 'With Function Modifier', result.first[:name]
  end

end

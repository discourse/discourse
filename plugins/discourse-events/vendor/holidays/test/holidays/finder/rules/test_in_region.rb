require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/finder/rules/in_region'

class FinderRulesInRegionTests < Test::Unit::TestCase
  def setup
    @available = [:test]
    @subject = Holidays::Finder::Rules::InRegion
  end

  def test_returns_true_if_any_specified
    assert_equal(true, @subject.call([:any], @available))
  end

  def test_returns_true_if_exact_match_found
    assert_equal(true, @subject.call([:test], @available))
  end

  def test_returns_true_if_subregion_matches_parent
    assert_equal(true, @subject.call([:test_sub], @available))
  end
  
  def test_returns_true_if_subregion_matches_grandparent
    assert_equal(true, @subject.call([:test_sub_sub], @available))
  end

  def test_returns_true_if_subregion_is_in_available
    assert_equal(true, @subject.call([:test_sub], [:test, :test_sub]))
  end

  def test_returns_false_if_match_not_found
    assert_equal(false, @subject.call([:other], @available))
  end

  def test_returns_false_if_match_not_found_for_subregion
    assert_equal(false, @subject.call([:other_sub], @available))
  end

  def test_returns_true_if_request_includes_nonmatching_but_also_any
    assert_equal(true, @subject.call([:other_sub, :other, :any], @available))
  end
end

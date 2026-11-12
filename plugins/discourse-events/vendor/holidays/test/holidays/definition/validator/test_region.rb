require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/validator/region'

class RegionValidatorTests < Test::Unit::TestCase
  def setup
    @regions_repo = mock()
    @regions_repo.stubs(:loaded?).returns(false)
    @regions_repo.stubs(:all_generated).returns([])

    @subject = Holidays::Definition::Validator::Region.new(@regions_repo)
  end

  def test_returns_true_if_region_loaded_in_generated_files
    @regions_repo.expects(:all_generated).returns([:us])
    assert(@subject.valid?(:us))
  end

  def test_returns_true_if_region_is_in_regions_repository
    @regions_repo.expects(:loaded?).with(:custom).returns(true)
    assert(@subject.valid?(:custom))
  end

  def test_returns_false_if_region_does_not_exist_in_generated_files_or_regions_repo
    @regions_repo.expects(:loaded?).with(:unknown_region).returns(false)
    assert_equal(false, @subject.valid?(:unknown_region))
  end

  def test_returns_false_if_region_is_not_a_symbol
    assert_equal(false, @subject.valid?('not-a-symbol'))
  end

  def test_returns_true_if_region_is_any
    assert(@subject.valid?(:any))
  end

  def test_returns_true_if_wildcard_region_is_valid
    @regions_repo.expects(:all_generated).returns([:gb])
    assert(@subject.valid?(:gb_))
  end

  def test_returns_false_if_wildcard_region_is_invalid
    assert_equal(false, @subject.valid?(:somethingweird_))
  end

  def test_returns_false_if_malicious_region_is_given
    assert_equal(false, @subject.valid?(:"../../../test"))
  end

  def test_returns_true_with_multiple_underscores
    @regions_repo.expects(:loaded?).with(:some_test_region).returns(true)
    assert(@subject.valid?(:some_test_region))
  end
end

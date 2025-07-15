require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/finder/context/parse_options'

class ParseOptionsTests < Test::Unit::TestCase
  def setup
    @regions_repo = mock()
    @regions_repo.stubs(:loaded?).returns(false)

    @region_validator = mock()
    @region_validator.stubs(:valid?).returns(true)

    @definition_loader = mock()
    @definition_loader.stubs(:call)

    @subject = Holidays::Finder::Context::ParseOptions.new(
      @regions_repo,
      @region_validator,
      @definition_loader,
    )
  end

  def test_returns_observed_true_if_options_contains_observed_flag
    @regions_repo.expects(:parent_region_lookup).with(:ca).returns(:ca)
    observed = @subject.call([:ca, :observed])[1]
    assert_equal(true, observed)
  end

  def test_returns_observed_false_if_options_does_not_contain_observed_flag
    @regions_repo.expects(:parent_region_lookup).with(:ca).returns(:ca)
    observed = @subject.call([:ca])[1]
    assert_equal(false, observed)
  end

  def test_returns_informal_true_if_options_contains_informal_flag
    @regions_repo.expects(:parent_region_lookup).with(:ca).returns(:ca)
    informal = @subject.call([:ca, :informal])[2]
    assert_equal(true, informal)
  end

  def test_returns_informal_false_if_options_does_not_contain_informal_flag
    @regions_repo.expects(:parent_region_lookup).with(:ca).returns(:ca)
    informal = @subject.call([:ca])[2]
    assert_equal(false, informal)
  end

  def test_raises_error_if_regions_are_invalid
    @region_validator.stubs(:valid?).returns(false)

    assert_raise Holidays::InvalidRegion do
      @subject.call([:unknown_region])
    end
  end

  def test_wildcards_load_appropriate_regions
    @definition_loader.expects(:call).with(:ch).returns([:ch, :ch_zh])

    regions = @subject.call([:ch_]).first

    assert_equal([:ch, :ch_zh], regions)
    assert_equal(false, regions.include?(:ch_))
  end

  def test_does_nothing_if_region_is_already_loaded_and_is_parent
    @regions_repo.expects(:parent_region_lookup).with(:test).returns(nil)
    regions = @subject.call([:test]).first
    assert_equal([:test], regions)
  end

  def test_does_nothing_if_region_is_already_loaded_and_is_parent_but_is_custom
    @regions_repo.expects(:parent_region_lookup).with(:custom_region).returns(nil)
    @regions_repo.expects(:loaded?).with(:custom_region).returns(true)

    regions = @subject.call([:custom_region]).first
    assert_equal([:custom_region], regions)
  end

  def test_has_parent_loads_parent_region
    @regions_repo.expects(:parent_region_lookup).with(:subregion).returns(:parent)
    @regions_repo.expects(:loaded?).with(:parent).returns(false)
    @definition_loader.expects(:call).with(:parent).returns([:parent, :subregion])

    regions = @subject.call([:subregion]).first
    assert_equal([:subregion], regions)
  end

  def test_has_parent_already_loaded_does_not_load_again
    @regions_repo.expects(:parent_region_lookup).with(:subregion).returns(:parent)
    @regions_repo.expects(:loaded?).with(:parent).returns(false)
    @definition_loader.expects(:call).with(:parent).returns([:parent, :subregion])

    regions = @subject.call([:subregion]).first
    assert_equal([:subregion], regions)
  end

  def test_cannot_load_region_prefix_for_wildcard_raises_error
    @definition_loader.expects(:call).with(:ch).raises(LoadError)
    assert_raises Holidays::UnknownRegionError do
      @subject.call([:ch_])
    end
  end

  def test_cannot_load_region_not_wildcard_raises_error
    @regions_repo.expects(:parent_region_lookup).with(:ch).returns(:ch)
    @definition_loader.expects(:call).with(:ch).raises(LoadError)
    assert_raises Holidays::UnknownRegionError do
      @subject.call([:ch])
    end
  end

  def test_region_with_multiple_underscores_load_correctly
    @regions_repo.expects(:parent_region_lookup).with(:subregion_with_underscores).returns(:parent)
    @regions_repo.expects(:loaded?).with(:parent).returns(false)
    @definition_loader.expects(:call).with(:parent).returns([:parent, :subregion_with_underscores])

    regions = @subject.call([:subregion_with_underscores]).first
    assert_equal([:subregion_with_underscores], regions)
  end

  def test_blank_region_should_load_all_regions_available
    @regions_repo.expects(:all_generated).returns([:region1, :region2])
    @regions_repo.expects(:loaded?).with(:region1).returns(false)
    @regions_repo.expects(:loaded?).with(:region2).returns(true)
    @regions_repo.expects(:parent_region_lookup).with(:region1).returns(:region2)
    @definition_loader.expects(:call).with(:region2)

    regions = @subject.call.first
    assert_equal([:region1, :region2], regions)
  end

  def test_special_any_region_should_load_all_regions_available
    @regions_repo.expects(:all_generated).returns([:region1, :region2])
    @regions_repo.expects(:loaded?).with(:region1).returns(false)
    @regions_repo.expects(:loaded?).with(:region2).returns(true)
    @regions_repo.expects(:parent_region_lookup).with(:region1).returns(:region2)
    @definition_loader.expects(:call).with(:region2)

    regions = @subject.call(:any).first
    assert_equal([:region1, :region2], regions)
  end
end

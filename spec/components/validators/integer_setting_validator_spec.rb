require 'spec_helper'

describe IntegerSettingValidator do
  describe '#valid_value?' do

    shared_examples "for all IntegerSettingValidator opts" do
      it "returns false for blank values" do
        validator.valid_value?('').should == false
        validator.valid_value?(nil).should == false
      end

      it "returns false if value is not a valid integer" do
        validator.valid_value?('two').should == false
      end
    end

    context "without min and max" do
      subject(:validator) { described_class.new }

      include_examples "for all IntegerSettingValidator opts"

      it "returns true if value is a valid integer" do
        validator.valid_value?(1).should == true
        validator.valid_value?(-1).should == true
        validator.valid_value?('1').should == true
        validator.valid_value?('-1').should == true
      end
    end

    context "with min" do
      subject(:validator) { described_class.new(min: 2) }

      include_examples "for all IntegerSettingValidator opts"

      it "returns true if value is equal to min" do
        validator.valid_value?(2).should == true
        validator.valid_value?('2').should == true
      end

      it "returns true if value is greater than min" do
        validator.valid_value?(3).should == true
        validator.valid_value?('3').should == true
      end

      it "returns false if value is less than min" do
        validator.valid_value?(1).should == false
        validator.valid_value?('1').should == false
      end
    end

    context "with max" do
      subject(:validator) { described_class.new(max: 3) }

      include_examples "for all IntegerSettingValidator opts"

      it "returns true if value is equal to max" do
        validator.valid_value?(3).should == true
        validator.valid_value?('3').should == true
      end

      it "returns true if value is less than max" do
        validator.valid_value?(2).should == true
        validator.valid_value?('2').should == true
      end

      it "returns false if value is greater than min" do
        validator.valid_value?(4).should == false
        validator.valid_value?('4').should == false
      end
    end

    context "with min and max" do
      subject(:validator) { described_class.new(min: -1, max: 3) }

      include_examples "for all IntegerSettingValidator opts"

      it "returns true if value is in range" do
        validator.valid_value?(-1).should == true
        validator.valid_value?(0).should == true
        validator.valid_value?(3).should == true
      end

      it "returns false if value is out of range" do
        validator.valid_value?(4).should == false
        validator.valid_value?(-2).should == false
      end
    end
  end
end

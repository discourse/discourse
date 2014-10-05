require 'spec_helper'

describe EmailSettingValidator do
  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      validator.valid_value?('').should == true
      validator.valid_value?(nil).should == true
    end

    it "returns true if value is a valid email address" do
      validator.valid_value?('vader@example.com').should == true
    end

    it "returns false if value is not a valid email address" do
      validator.valid_value?('my house').should == false
    end
  end
end

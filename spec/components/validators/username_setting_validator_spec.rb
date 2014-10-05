require 'spec_helper'

describe UsernameSettingValidator do
  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      validator.valid_value?('').should == true
      validator.valid_value?(nil).should == true
    end

    it "returns true if value matches an existing user's username" do
      Fabricate(:user, username: 'vader')
      validator.valid_value?('vader').should == true
    end

    it "returns false if value does not match a user's username" do
      validator.valid_value?('no way').should == false
    end
  end
end

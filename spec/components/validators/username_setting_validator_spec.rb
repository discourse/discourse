require 'spec_helper'

describe UsernameSettingValidator do
  describe '#valid_value?' do
    it "returns true for blank values" do
      described_class.valid_value?('').should == true
      described_class.valid_value?(nil).should == true
    end

    it "returns true if value matches an existing user's username" do
      Fabricate(:user, username: 'vader')
      described_class.valid_value?('vader').should == true
    end

    it "returns false if value does not match a user's username" do
      described_class.valid_value?('no way').should == false
    end
  end
end

# encoding: utf-8
require 'spec_helper'
require_dependency 'avatar_detector'

describe AvatarDetector do

  describe "construction" do

    it "raises an error without a user" do
      -> { AvatarDetector.new(nil) }.should raise_error
    end

    it "raises an error on a non-user object" do
      -> { AvatarDetector.new(Array.new) }.should raise_error
    end

  end

  describe "has_custom_avatar?" do

    describe "with a user" do
      let(:user) { User.new(use_uploaded_avatar: true) }
      let(:avatar_detector) { AvatarDetector.new(user) }

      describe "when the user doesn't have an uploaded_avatar_path" do

        before do
          user.stubs(:uploaded_avatar_path)
        end

        it "returns true if they have a custom gravatar" do
          avatar_detector.expects(:has_custom_gravatar?).returns(true)
          avatar_detector.has_custom_avatar?.should be_true
        end

        it "returns false if they don't have a custom gravatar" do
          avatar_detector.expects(:has_custom_gravatar?).returns(false)
          avatar_detector.has_custom_avatar?.should be_false
        end
      end


      context "when the user doesn't have an uploaded_avatar_path" do
        let(:user) { User.new(use_uploaded_avatar: true) }
        let(:avatar_detector) { AvatarDetector.new(user) }

        describe "when the user has an uploaded avatar" do
          before do
            user.expects(:uploaded_avatar_path).returns("/some/uploaded/file.png")
          end

          it "returns true" do
            avatar_detector.has_custom_avatar?.should be_true
          end

          it "doesn't call has_custom_gravatar" do
            avatar_detector.expects(:has_custom_gravatar?).never
            avatar_detector.has_custom_avatar?
          end

        end
      end

    end
  end

end
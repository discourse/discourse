# frozen_string_literal: true

require 'rails_helper'

describe DirectoryItemSerializer do

  context "serializes additional user attributes when site setting is enabled" do

    it "serializes when the setting is on" do
      SiteSetting.user_directory_includes_profile = true
      expect(DirectoryItemSerializer.user_serializer).to eq(::UserSerializer)
    end

    it "doesn't serialize when the setting is off" do
      SiteSetting.user_directory_includes_profile = false
      expect(DirectoryItemSerializer.user_serializer).to eq(DirectoryItemSerializer::DirectoryItemUserSerializer)
    end
  end

end

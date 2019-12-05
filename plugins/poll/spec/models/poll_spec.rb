# frozen_string_literal: true

require 'rails_helper'

describe ::DiscoursePoll::Poll do
  describe ".transform_for_user_field_override" do
    it "Transforms UserField name if a matching CustomUserField is present" do
      user_field_name = "Something Cool"
      user_field = Fabricate(:user_field, name: user_field_name)
      expect(::DiscoursePoll::Poll.transform_for_user_field_override(user_field_name)).to eq("user_field_#{user_field.id}")
    end

    it "does not transform UserField name if a matching CustomUserField is not present" do
      user_field_name = "Something Cool"
      user_field = Fabricate(:user_field, name: "Something Else!")
      expect(::DiscoursePoll::Poll.transform_for_user_field_override(user_field_name)).to eq(user_field_name)
    end
  end
end

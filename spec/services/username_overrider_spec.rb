# frozen_string_literal: true

require 'rails_helper'

describe UsernameOverrider do
  common_test_cases = [
    [
      "overrides the username if a new name is different",
      "john", "bill", "bill", false
    ],
    [
      "does not change the username if a new name is the same",
      "john", "john", "john", false
    ],
    [
      "overrides the username if a new name has another case",
      "john", "JoHN", "JoHN", false
    ]
  ]

  context "unicode_usernames is off" do
    before do
      SiteSetting.unicode_usernames = false
    end

    [
      *common_test_cases,
      [
        "overrides the username if a new name after unicode normalization is different only in case",
        "john", "john¥¥", "john"
      ],
    ].each do |testcase_name, current, new, overrode|
      it "#{testcase_name}" do
        user = Fabricate(:user, username: current)
        UsernameOverrider.override(user, new)
        expect(user.username).to eq(overrode)
      end
    end

    it "overrides the username with username suggestions in case the username is already taken" do
      user = Fabricate(:user, username: "bill")
      Fabricate(:user, username: "john")

      UsernameOverrider.override(user, "john")

      expect(user.username).to eq("john1")
    end
  end

  context "unicode_usernames is on" do
    before do
      SiteSetting.unicode_usernames = true
    end

    [
      *common_test_cases,
      [
        "overrides the username if a new name after unicode normalization is different only in case",
        "lo\u0308we", "L\u00F6wee", "L\u00F6wee"
      ],
    ].each do |testcase_name, current, new, overrode|
      it "#{testcase_name}" do
        user = Fabricate(:user, username: current)
        UsernameOverrider.override(user, new)
        expect(user.username).to eq(overrode)
      end
    end
  end
end

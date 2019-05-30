# frozen_string_literal: true

require 'rails_helper'

describe Developer do
  it "can correctly flag developer accounts" do
    user = Fabricate(:user)
    guardian = Guardian.new(user)

    expect(guardian.is_developer?).to eq(false)

    Developer.create!(user_id: user.id)

    # not an admin so not a developer yet
    expect(guardian.is_developer?).to eq(false)

    user.update_columns(admin: true)

    expect(guardian.is_developer?).to eq(true)
  end
end

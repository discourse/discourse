# frozen_string_literal: true

require 'rails_helper'

describe Developer do
  it "can correctly flag developer accounts" do
    user = Fabricate(:user)
    guardian = Guardian.new(user)

    expect(guardian.is_developer?).to eq(false)

    Developer.create!(user_id: user.id)
    expect(guardian.is_developer?).to eq(true)
  end
end

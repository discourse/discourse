# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::Customer do
  let(:user) { Fabricate(:user) }
  let(:stripe_customer) { { id: "cus_id4567" } }

  it "has a table name" do
    expect(described_class.table_name).to eq "discourse_subscriptions_customers"
  end

  it "creates" do
    customer = described_class.create_customer(user, stripe_customer)
    expect(customer.customer_id).to eq "cus_id4567"
    expect(customer.user_id).to eq user.id
  end

  it "has a user scope" do
    described_class.create_customer(user, stripe_customer)
    customer = described_class.find_user(user)
    expect(customer.customer_id).to eq "cus_id4567"
  end
end

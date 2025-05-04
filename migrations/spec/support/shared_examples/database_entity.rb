# frozen_string_literal: true

RSpec.shared_examples "a database entity" do
  it "has SQL constant" do
    expect(subject).to have_constant(:SQL)
  end

  it "responds to .create" do
    expect(subject).to respond_to(:create)
  end
end

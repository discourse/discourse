# frozen_string_literal: true

RSpec.describe IpAddressFormatValidator do
  subject(:validate) { validator.validate_each(record, :ip_address, record.ip_address) }

  let(:record) { Fabricate.build(:screened_ip_address, ip_address: "99.232.23.123") }
  let(:validator) { described_class.new(attributes: :ip_address) }

  it "accepts 99.232.23.123" do
    record.ip_address = ("99.232.23.123")
    validate
    expect(record.errors[:ip_address]).not_to be_present
  end

  it "accepts 99.232.0.0/16" do
    record.ip_address = ("99.232.0.0/16")
    validate
    expect(record.errors[:ip_address]).not_to be_present
  end

  it "accepts fd12:db8::ff00:42:8329" do
    record.ip_address = ("fd12:db8::ff00:42:8329")
    validate
    expect(record.errors[:ip_address]).not_to be_present
  end

  it "accepts fc00::/7" do
    record.ip_address = ("fc00::/7")
    validate
    expect(record.errors[:ip_address]).not_to be_present
  end

  it "adds an error for a nil IP address" do
    record.ip_address = nil
    validate
    expect(record.errors[:ip_address]).to be_present
  end

  it "adds an error for an invalid IP address" do
    record.ip_address = "99.99.99"
    validate
    expect(record.errors[:ip_address]).to be_present
  end
end

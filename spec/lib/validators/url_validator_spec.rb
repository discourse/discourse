# frozen_string_literal: true

RSpec.describe UrlValidator do
  subject(:validate) { validator.validate_each(record, :website, record.website) }

  let(:record) { Fabricate.build(:user_profile, user: Fabricate.build(:user)) }
  let(:validator) { described_class.new(attributes: :website) }

  it "http://https://google.com should not be valid" do
    record.website = ("http://https://google.com")
    validate
    expect(record.errors[:website]).to be_present
  end

  it "http://google/ should not be valid" do
    record.website = ("http://google/")
    validate
    expect(record.errors[:website]).to be_present
  end

  it "ftp://ftp.google.com should not be valid" do
    record.website = ("ftp://ftp.google.com")
    validate
    expect(record.errors[:website]).to be_present
  end

  it "http:///what.is.this should not be valid" do
    record.website = ("http:///what.is.this")
    validate
    expect(record.errors[:website]).to be_present
  end

  it "http://meta.discourse.org TEST should not be valid" do
    record.website = ("http://meta.discourse.org TEST")
    validate
    expect(record.errors[:website]).to be_present
  end

  it "http://discourse.productions should be valid" do
    record.website = ("http://discourse.productions")
    validate
    expect(record.errors[:website]).to_not be_present
  end

  it "https://google.com should be valid" do
    record.website = ("https://google.com")
    validate
    expect(record.errors[:website]).to_not be_present
  end

  it "http://xn--nw2a.xn--j6w193g/ should be valid" do
    record.website = ("http://xn--nw2a.xn--j6w193g/")
    validate
    expect(record.errors[:website]).to_not be_present
  end

  it "http://見.香港/ should be valid" do
    record.website = ("http://見.香港/")
    validate
    expect(record.errors[:website]).to_not be_present
  end
end

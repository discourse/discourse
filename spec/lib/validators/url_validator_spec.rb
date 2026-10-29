# frozen_string_literal: true

RSpec.describe UrlValidator do
  subject(:validate) { validator.validate_each(record, :website, record.website) }

  let(:record) { Fabricate.build(:user_profile, user: Fabricate.build(:user)) }
  let(:validator) { described_class.new(attributes: :website) }

  shared_examples "url validator for invalid_url" do |invalid_url|
    it "#{invalid_url} should not be valid" do
      record.website = invalid_url
      validate
      expect(record.errors[:website]).to be_present
    end
  end

  include_examples "url validator for invalid_url", "http://https://google.com"
  include_examples "url validator for invalid_url", "http://google/"
  include_examples "url validator for invalid_url", "ftp://ftp.google.com"
  include_examples "url validator for invalid_url", "http:///what.is.this"
  include_examples "url validator for invalid_url", "http://meta.discourse.org TEST"

  shared_examples "url validator for valid_url" do |valid_url|
    it "#{valid_url} should be valid" do
      record.website = valid_url
      validate
      expect(record.errors[:website]).to_not be_present
    end
  end

  include_examples "url validator for valid_url", "http://discourse.productions"
  include_examples "url validator for valid_url", "https://google.com"
  include_examples "url validator for valid_url", "http://xn--nw2a.xn--j6w193g/"
  include_examples "url validator for valid_url", "http://見.香港/"
end

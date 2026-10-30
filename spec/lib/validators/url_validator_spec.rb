# frozen_string_literal: true

RSpec.describe UrlValidator do
  subject(:validate) { validator.validate_each(record, :website, record.website) }

  let(:record) { Fabricate.build(:user_profile, user: Fabricate.build(:user)) }
  let(:validator) { described_class.new(attributes: :website) }

  shared_examples "an invalid website URL" do |url|
    it "#{url} should not be valid" do
      record.website = url
      validate
      expect(record.errors[:website]).to be_present
    end
  end

  it_behaves_like "an invalid website URL", "http://https://google.com"

  it_behaves_like "an invalid website URL", "http://google/"

  it_behaves_like "an invalid website URL", "ftp://ftp.google.com"

  it_behaves_like "an invalid website URL", "http:///what.is.this"

  it_behaves_like "an invalid website URL", "http://meta.discourse.org TEST"

  shared_examples "a valid website URL" do |url|
    it "#{url} should be valid" do
      record.website = url
      validate
      expect(record.errors[:website]).to_not be_present
    end
  end

  it_behaves_like "a valid website URL", "http://discourse.productions"

  it_behaves_like "a valid website URL", "https://google.com"

  it_behaves_like "a valid website URL", "http://xn--nw2a.xn--j6w193g/"

  it_behaves_like "a valid website URL", "http://見.香港/"
end

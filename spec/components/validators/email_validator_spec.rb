require 'rails_helper'

describe EmailValidator do

  let(:record) {}
  let(:validator) { described_class.new(attributes: :email) }
  subject(:validate) { validator.validate_each(record, :email, record.email) }

  def blocks?(email)
    user = Fabricate.build(:user, email: email)
    validator = EmailValidator.new(attributes: :email)
    validator.validate_each(user, :email, user.email)
    user.errors[:email].present?
  end

  context "blocked email" do
    it "doesn't add an error when email doesn't match a blocked email" do
      expect(blocks?('sam@sam.com')).to eq(false)
    end

    it "adds an error when email matches a blocked email" do
      ScreenedEmail.create!(email: 'sam@sam.com', action_type: ScreenedEmail.actions[:block])
      expect(blocks?('sam@sam.com')).to eq(true)
      expect(blocks?('SAM@sam.com')).to eq(true)
    end

    it "blocks based on email_domains_blacklist" do
      SiteSetting.email_domains_blacklist = "email.com|mail.com|e-mail.com"
      expect(blocks?('sam@email.com')).to eq(true)
      expect(blocks?('sam@EMAIL.com')).to eq(true)
      expect(blocks?('sam@bob.email.com')).to eq(true)
      expect(blocks?('sam@e-mail.com')).to eq(true)
      expect(blocks?('sam@googlemail.com')).to eq(false)
    end

    it "blocks based on email_domains_whitelist" do
      SiteSetting.email_domains_whitelist = "googlemail.com|email.com"
      expect(blocks?('sam@email.com')).to eq(false)
      expect(blocks?('sam@EMAIL.com')).to eq(false)
      expect(blocks?('sam@bob.email.com')).to eq(false)
      expect(blocks?('sam@e-mail.com')).to eq(true)
      expect(blocks?('sam@googlemail.com')).to eq(false)
      expect(blocks?('sam@email.computers.are.evil.com')).to eq(true)
    end
  end

  context '.email_regex' do
    it 'should match valid emails' do
      expect(!!('test@discourse.org' =~ EmailValidator.email_regex)).to eq(true)
    end

    it 'should not match invalid emails' do
      ['testdiscourse.org', 'test@discourse.org; a@discourse.org', 'random'].each do |email|
        expect(!!(email =~ EmailValidator.email_regex)).to eq(false)
      end
    end
  end

end

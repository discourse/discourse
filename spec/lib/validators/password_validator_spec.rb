# frozen_string_literal: true

RSpec.describe PasswordValidator do
  subject(:validate) { validator.validate_each(record, :password, @password) }

  let(:validator) { described_class.new(attributes: :password) }

  describe "password required" do
    let(:record) do
      u = Fabricate.build(:user, password: @password)
      u.password_required!
      u
    end

    it "adds an error when password is blank" do
      @password = ""
      validate
      expect(record.errors[:password]).to be_present
    end

    it "adds an error when password is nil" do
      @password = nil
      validate
      expect(record.errors[:password]).to be_present
    end

    it "validation required if password is required" do
      expect(record.password_validation_required?).to eq(true)
    end

    it "validation not required after save until a new password is set" do
      @password = "myoldpassword"
      record.save!
      record.reload
      expect(record.password_validation_required?).to eq(false)
      record.password = "mynewpassword"
      expect(record.password_validation_required?).to eq(true)
    end
  end

  describe "password not required" do
    let(:record) { Fabricate.build(:user, password: @password) }

    it "doesn't add an error if password is not required" do
      @password = nil
      validate
      expect(record.errors[:password]).not_to be_present
    end

    it "validation required if a password is set" do
      @password = "mygameshow"
      expect(record.password_validation_required?).to eq(true)
    end
  end
end

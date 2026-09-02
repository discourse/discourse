# frozen_string_literal: true

RSpec.describe PasswordValidator do
  subject(:validate) { validator.validate_each(record, :password, password_state[:value]) }

  let(:validator) { described_class.new(attributes: :password) }
  let(:password_state) { {} }

  describe "password required" do
    let(:record) do
      u = Fabricate.build(:user, password: password_state[:value])
      u.password_required!
      u
    end

    it "adds an error when password is blank" do
      password_state[:value] = ""
      validate
      expect(record.errors[:password]).to be_present
    end

    it "adds an error when password is nil" do
      password_state[:value] = nil
      validate
      expect(record.errors[:password]).to be_present
    end

    it "validation required if password is required" do
      expect(record.password_validation_required?).to eq(true)
    end

    it "validation not required after save until a new password is set" do
      password_state[:value] = "myoldpassword"
      record.save!
      record.reload
      expect(record.password_validation_required?).to eq(false)
      record.password = "mynewpassword"
      expect(record.password_validation_required?).to eq(true)
    end
  end

  describe "password not required" do
    let(:record) { Fabricate.build(:user, password: password_state[:value]) }

    it "doesn't add an error if password is not required" do
      password_state[:value] = nil
      validate
      expect(record.errors[:password]).not_to be_present
    end

    it "validation required if a password is set" do
      password_state[:value] = "mygameshow"
      expect(record.password_validation_required?).to eq(true)
    end
  end
end

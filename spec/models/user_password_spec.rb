# frozen_string_literal: true

RSpec.describe UserPassword do
  context "when saving passwords through User" do
    it "should save when first time password" do
      pw = "helloworldakjdlakjfalkjfd"
      u = Fabricate(:user, password: nil)
      u.password = pw
      u.save
      expect(u.confirm_password?(pw)).to eq true
    end

    it "should save when updated existing password" do
      pw = SecureRandom.hex
      u = Fabricate(:user, password: "lajdlaksjfalkfjaelkfj")
      u.update!(password: pw)
      expect(u.confirm_password?(pw)).to eq true
    end
  end
  context "for validations" do
    it "should validate presence of user_id" do
      user_password = Fabricate.build(:user_password, user: nil)

      expect(user_password).not_to be_valid
      expect(user_password.errors[:user]).to include("must exist")
    end
  end
end

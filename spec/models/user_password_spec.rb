# frozen_string_literal: true

RSpec.describe UserPassword do
  context "for validations" do
    it "should validate presence of user_id" do
      user_password = Fabricate.build(:user_password, user_id: nil)

      expect(user_password).not_to be_valid
      expect(user_password.errors[:user_id]).to include("can't be blank")
    end

    it "should validate presence of password_hash" do
      user_password = Fabricate.build(:user_password)
      user_password.password_hash = nil

      expect(user_password).not_to be_valid
      expect(user_password.errors[:password_hash]).to include("can't be blank")
    end

    it "should validate that password_hash is 64 characters long" do
      user_password = Fabricate.build(:user_password)
      user_password.password_hash = "a" * 65

      expect(user_password).not_to be_valid

      expect(user_password.errors[:password_hash]).to include(
        "is the wrong length (should be 64 characters)",
      )
    end

    it "should validate uniqueness of password_hash scoped to user_id" do
      password = "password"
      user_password_1 = Fabricate(:user_password, password:)
      user = user_password_1.user

      user_password_2 =
        Fabricate.build(
          :user_password,
          user:,
          password:,
          password_salt: user_password_1.password_salt,
          password_algorithm: user_password_1.password_algorithm,
        )

      expect(user_password_2).not_to be_valid
      expect(user_password_2.errors[:password_hash]).to include("has already been taken")
    end

    it "should validate uniqueness of user_id scoped to password_expired_at" do
      user = Fabricate(:user)
      user_password_1 = Fabricate.create(:user_password, user:, password_expired_at: nil)

      user_password_2 =
        Fabricate.build(:user_password, user: user_password_1.user, password_expired_at: nil)

      expect(user_password_2).not_to be_valid
      expect(user_password_2.errors[:user_id]).to include("has already been taken")
    end

    it "should validate presence of password_salt" do
      user_password = Fabricate.build(:user_password)
      user_password.password_salt = nil

      expect(user_password).not_to be_valid
      expect(user_password.errors[:password_salt]).to include("can't be blank")
    end

    it "should validate that password_salt is 32 characters long" do
      user_password = Fabricate.build(:user_password)
      user_password.password_salt = "a" * 33

      expect(user_password).not_to be_valid

      expect(user_password.errors[:password_salt]).to include(
        "is the wrong length (should be 32 characters)",
      )
    end

    it "should validate presence of password_algorithm" do
      user_password = Fabricate.build(:user_password)
      user_password.password_algorithm = nil

      expect(user_password).not_to be_valid
      expect(user_password.errors[:password_algorithm]).to include("can't be blank")
    end

    it "should validate that password_algorithm is at most 64 characters long" do
      user_password = Fabricate.build(:user_password)
      user_password.password_algorithm = "a" * 65

      expect(user_password).not_to be_valid
      expect(user_password.errors[:password_algorithm]).to include(
        "is too long (maximum is 64 characters)",
      )
    end
  end
end

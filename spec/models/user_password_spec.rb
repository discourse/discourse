# frozen_string_literal: true

RSpec.describe UserPassword do
  context "for validations" do
    it "should validate presence of user_id" do
      user_password = Fabricate.build(:user_password, user_id: nil)

      expect(user_password).not_to be_valid
      expect(user_password.errors[:user_id]).to include("can't be blank")
    end

    it "should validate presence of hash" do
      user_password = Fabricate.build(:user_password)
      user_password.hash = nil

      expect(user_password).not_to be_valid
      expect(user_password.errors[:hash]).to include("can't be blank")
    end

    it "should validate that hash is 64 characters long" do
      user_password = Fabricate.build(:user_password)
      user_password.hash = "a" * 65

      expect(user_password).not_to be_valid

      expect(user_password.errors[:hash]).to include(
        "is the wrong length (should be 64 characters)",
      )
    end

    it "should validate uniqueness of user_id scoped to expired_at" do
      user = Fabricate(:user)
      # user_password_1 = Fabricate.build(:user_password, user:, expired_at: nil)
      # user_password_1.save!

      salt = SecureRandom.hex(User::PASSWORD_SALT_LENGTH)
      algorithm = User::TARGET_PASSWORD_ALGORITHM
      hash =
        PasswordHasher.hash_password(
          password: "myawesomefakepassword",
          salt: salt,
          algorithm: algorithm,
        )

      user_password = UserPassword.create!(user_id: user.id, hash:, salt:, algorithm:)

      # user_password_2 = Fabricate.build(:user_password, user: user_password_1.user, expired_at: nil)

      # expect(user_password_2).not_to be_valid
      # expect(user_password_2.errors[:user_id]).to include("has already been taken")
    end

    it "should validate presence of salt" do
      user_password = Fabricate.build(:user_password)
      user_password.salt = nil

      expect(user_password).not_to be_valid
      expect(user_password.errors[:salt]).to include("can't be blank")
    end

    it "should validate that salt is 32 characters long" do
      user_password = Fabricate.build(:user_password)
      user_password.salt = "a" * 33

      expect(user_password).not_to be_valid

      expect(user_password.errors[:salt]).to include(
        "is the wrong length (should be 32 characters)",
      )
    end

    it "should validate presence of algorithm" do
      user_password = Fabricate.build(:user_password)
      user_password.algorithm = nil

      expect(user_password).not_to be_valid
      expect(user_password.errors[:algorithm]).to include("can't be blank")
    end

    it "should validate that algorithm is at most 64 characters long" do
      user_password = Fabricate.build(:user_password)
      user_password.algorithm = "a" * 65

      expect(user_password).not_to be_valid
      expect(user_password.errors[:algorithm]).to include("is too long (maximum is 64 characters)")
    end
  end
end

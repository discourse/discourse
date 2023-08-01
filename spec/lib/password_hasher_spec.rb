# frozen_string_literal: true

describe PasswordHasher do
  def hash(password: "mypass", salt: "mysalt", algorithm:)
    PasswordHasher.hash_password(password: password, salt: salt, algorithm: algorithm)
  end

  describe "pbkdf2-sha256 algorithm" do
    it "can hash correctly" do
      result = hash(password: "mypass", salt: "mysalt", algorithm: "$pbkdf2-sha256$i=3,l=32$")
      expect(result).to eq("8d4f9a685ff73eef7b06e07ab5889784775290a0a9cebb6eb4492a695c93a51e")
    end

    it "supports different iteration numbers" do
      iter_3 = hash(algorithm: "$pbkdf2-sha256$i=3,l=32$")
      iter_4 = hash(algorithm: "$pbkdf2-sha256$i=4,l=32$")

      expect(iter_3).not_to eq(iter_4)
    end

    it "raises an error for non-standard length" do
      expect { hash(algorithm: "$pbkdf2-sha256$i=3,l=20$") }.to raise_error(
        PasswordHasher::UnsupportedAlgorithmError,
      )
    end

    it "raises an error for missing length param" do
      expect { hash(algorithm: "$pbkdf2-sha256$i=3$") }.to raise_error(
        PasswordHasher::UnsupportedAlgorithmError,
      )
    end

    it "raises an error for missing iteration param" do
      expect { hash(algorithm: "$pbkdf2-sha256$l=32$") }.to raise_error(
        PasswordHasher::UnsupportedAlgorithmError,
      )
    end

    it "raises an error for missing salt" do
      expect { hash(salt: nil, algorithm: "$pbkdf2-sha256$l=32,i=3$") }.to raise_error(
        ArgumentError,
      )
    end

    it "raises an error for missing password" do
      expect { hash(password: nil, algorithm: "$pbkdf2-sha256$l=32,i=3$") }.to raise_error(
        ArgumentError,
      )
    end
  end

  it "raises error for invalid algorithm" do
    expect { hash(algorithm: "$pbkdf2-sha256$l=32$somethinginvalid") }.to raise_error(
      PasswordHasher::InvalidAlgorithmError,
    )
  end

  it "raises error for unknown algorithm" do
    expect { hash(algorithm: "$pbkdf2-invalid$l=32$") }.to raise_error(
      PasswordHasher::UnsupportedAlgorithmError,
    )
    expect { hash(algorithm: "$unknown$l=32$") }.to raise_error(
      PasswordHasher::UnsupportedAlgorithmError,
    )
  end
end

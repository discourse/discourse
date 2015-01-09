require 'pbkdf2'

describe Pbkdf2 do
  # trivial test to ensure this does not regress during extraction 
  it "hashes stuff correctly" do 
    expect(Pbkdf2.hash_password('test', 'abcd', 100)).to eq("0313a6aca54dd4c5d82a699a8a0f0ffb0191b4ef62414b8d9dbc11c0c5ac04da")
    expect(Pbkdf2.hash_password('test', 'abcd', 101)).to eq("c7a7b2891bf8e6f82d08cf8d83824edcf6c7c6bacb6a741f38e21fc7977bd20f")
  end
end

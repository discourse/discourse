require File.expand_path(File.join(File.dirname(__FILE__), "..", "spec_helper"))

describe "The BCrypt engine" do
  specify "should calculate the optimal cost factor to fit in a specific time" do
    first = BCrypt::Engine.calibrate(100)
    second = BCrypt::Engine.calibrate(400)
    second.should > first
  end
end

describe "Generating BCrypt salts" do

  specify "should produce strings" do
    BCrypt::Engine.generate_salt.should be_an_instance_of(String)
  end

  specify "should produce random data" do
    BCrypt::Engine.generate_salt.should_not equal(BCrypt::Engine.generate_salt)
  end

  specify "should raise a InvalidCostError if the cost parameter isn't numeric" do
    lambda { BCrypt::Engine.generate_salt('woo') }.should raise_error(BCrypt::Errors::InvalidCost)
  end

  specify "should raise a InvalidCostError if the cost parameter isn't greater than 0" do
    lambda { BCrypt::Engine.generate_salt(-1) }.should raise_error(BCrypt::Errors::InvalidCost)
  end
end

describe "Autodetecting of salt cost" do

  specify "should work" do
    BCrypt::Engine.autodetect_cost("$2a$08$hRx2IVeHNsTSYYtUWn61Ou").should eq 8
    BCrypt::Engine.autodetect_cost("$2a$05$XKd1bMnLgUnc87qvbAaCUu").should eq 5
    BCrypt::Engine.autodetect_cost("$2a$13$Lni.CZ6z5A7344POTFBBV.").should eq 13
  end

end

describe "Generating BCrypt hashes" do

  class MyInvalidSecret
    undef to_s
  end

  before :each do
    @salt = BCrypt::Engine.generate_salt(4)
    @password = "woo"
  end

  specify "should produce a string" do
    BCrypt::Engine.hash_secret(@password, @salt).should be_an_instance_of(String)
  end

  specify "should raise an InvalidSalt error if the salt is invalid" do
    lambda { BCrypt::Engine.hash_secret(@password, 'nino') }.should raise_error(BCrypt::Errors::InvalidSalt)
  end

  specify "should raise an InvalidSecret error if the secret is invalid" do
    lambda { BCrypt::Engine.hash_secret(MyInvalidSecret.new, @salt) }.should raise_error(BCrypt::Errors::InvalidSecret)
    lambda { BCrypt::Engine.hash_secret(nil, @salt) }.should_not raise_error(BCrypt::Errors::InvalidSecret)
    lambda { BCrypt::Engine.hash_secret(false, @salt) }.should_not raise_error(BCrypt::Errors::InvalidSecret)
  end

  specify "should call #to_s on the secret and use the return value as the actual secret data" do
    BCrypt::Engine.hash_secret(false, @salt).should == BCrypt::Engine.hash_secret("false", @salt)
  end

  specify "should be interoperable with other implementations" do
    # test vectors from the OpenWall implementation <http://www.openwall.com/crypt/>
    test_vectors = [
      ["U*U", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.E5YPO9kmyuRGyh0XouQYb4YMJKvyOeW"],
      ["U*U*", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.VGOzA784oUp/Z0DY336zx7pLYAy0lwK"],
      ["U*U*U", "$2a$05$XXXXXXXXXXXXXXXXXXXXXO", "$2a$05$XXXXXXXXXXXXXXXXXXXXXOAcXxm9kjPGEMsLznoKqmqw7tc8WCx4a"],
      ["", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.7uG0VCzI2bS7j6ymqJi9CdcdxiRTWNy"],
      ["0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", "$2a$05$abcdefghijklmnopqrstuu", "$2a$05$abcdefghijklmnopqrstuu5s2v8.iXieOjg/.AySBTTZIIVFJeBui"]
    ]
    for secret, salt, test_vector in test_vectors
      BCrypt::Engine.hash_secret(secret, salt).should eql(test_vector)
    end
  end
end

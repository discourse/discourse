require File.expand_path(File.join(File.dirname(__FILE__), "..", "spec_helper"))

describe "Creating a hashed password" do

  before :each do
    @secret = "wheedle"
    @password = BCrypt::Password.create(@secret, :cost => 4)
  end

  specify "should return a BCrypt::Password" do
    @password.should be_an_instance_of(BCrypt::Password)
  end

  specify "should return a valid bcrypt password" do
    lambda { BCrypt::Password.new(@password) }.should_not raise_error
  end

  specify "should behave normally if the secret is not a string" do
    lambda { BCrypt::Password.create(nil) }.should_not raise_error(BCrypt::Errors::InvalidSecret)
    lambda { BCrypt::Password.create({:woo => "yeah"}) }.should_not raise_error(BCrypt::Errors::InvalidSecret)
    lambda { BCrypt::Password.create(false) }.should_not raise_error(BCrypt::Errors::InvalidSecret)
  end

  specify "should tolerate empty string secrets" do
    lambda { BCrypt::Password.create( "\n".chop  ) }.should_not raise_error
    lambda { BCrypt::Password.create( ""         ) }.should_not raise_error
    lambda { BCrypt::Password.create( String.new ) }.should_not raise_error
  end
end

describe "Reading a hashed password" do
  before :each do
    @secret = "U*U"
    @hash = "$2a$05$CCCCCCCCCCCCCCCCCCCCC.E5YPO9kmyuRGyh0XouQYb4YMJKvyOeW"
  end

  specify "the cost is too damn high" do
    lambda {
      BCrypt::Password.create("hello", :cost => 32)
    }.should raise_error(ArgumentError)
  end

  specify "the cost should be set to the default if nil" do
    BCrypt::Password.create("hello", :cost => nil).cost.should equal(BCrypt::Engine::DEFAULT_COST)
  end

  specify "the cost should be set to the default if empty hash" do
    BCrypt::Password.create("hello", {}).cost.should equal(BCrypt::Engine::DEFAULT_COST)
  end

  specify "the cost should be set to the passed value if provided" do
    BCrypt::Password.create("hello", :cost => 5).cost.should equal(5)
  end

  specify "the cost should be set to the global value if set" do
    BCrypt::Engine.cost = 5
    BCrypt::Password.create("hello").cost.should equal(5)
    # unset the global value to not affect other tests
    BCrypt::Engine.cost = nil
  end

  specify "the cost should be set to an overridden constant for backwards compatibility" do
    # suppress "already initialized constant" warning
    old_verbose, $VERBOSE = $VERBOSE, nil
    old_default_cost = BCrypt::Engine::DEFAULT_COST

    BCrypt::Engine::DEFAULT_COST = 5
    BCrypt::Password.create("hello").cost.should equal(5)

    # reset default to not affect other tests
    BCrypt::Engine::DEFAULT_COST = old_default_cost
    $VERBOSE = old_verbose
  end

  specify "should read the version, cost, salt, and hash" do
    password = BCrypt::Password.new(@hash)
    password.version.should eql("2a")
    password.cost.should equal(5)
    password.salt.should eql("$2a$05$CCCCCCCCCCCCCCCCCCCCC.")
    password.salt.class.should eq String
    password.checksum.should eq("E5YPO9kmyuRGyh0XouQYb4YMJKvyOeW")
    password.checksum.class.should eq String
    password.to_s.should eql(@hash)
  end

  specify "should raise an InvalidHashError when given an invalid hash" do
    lambda { BCrypt::Password.new('weedle') }.should raise_error(BCrypt::Errors::InvalidHash)
  end
end

describe "Comparing a hashed password with a secret" do
  before :each do
    @secret = "U*U"
    @hash = "$2a$05$CCCCCCCCCCCCCCCCCCCCC.E5YPO9kmyuRGyh0XouQYb4YMJKvyOeW"
    @password = BCrypt::Password.create(@secret)
  end

  specify "should compare successfully to the original secret" do
    (@password == @secret).should be(true)
  end

  specify "should compare unsuccessfully to anything besides original secret" do
    (@password == "@secret").should be(false)
  end
end

describe "Validating a generated salt" do
  specify "should not accept an invalid salt" do
    BCrypt::Engine.valid_salt?("invalid").should eq(false)
  end
  specify "should accept a valid salt" do
    BCrypt::Engine.valid_salt?(BCrypt::Engine.generate_salt).should eq(true)
  end
end

describe "Validating a password hash" do
  specify "should not accept an invalid password" do
    BCrypt::Password.valid_hash?("i_am_so_not_valid").should be_false
  end
  specify "should accept a valid password" do
    BCrypt::Password.valid_hash?(BCrypt::Password.create "i_am_so_valid").should be_true
  end
end

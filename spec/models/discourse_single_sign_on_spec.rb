require "spec_helper"

describe DiscourseSingleSignOn do
  before do
    @sso_url = "http://somesite.com/discourse_sso"
    @sso_secret = "shjkfdhsfkjh"

    SiteSetting.stubs("enable_sso").returns(true)
    SiteSetting.stubs("sso_url").returns(@sso_url)
    SiteSetting.stubs("sso_secret").returns(@sso_secret)
  end

  def make_sso
    sso = SingleSignOn.new
    sso.sso_url = "http://meta.discorse.org/topics/111"
    sso.sso_secret = "supersecret"
    sso.nonce = "testing"
    sso.email = "some@email.com"
    sso.username = "sam"
    sso.name = "sam saffron"
    sso.external_id = "100"
    sso.custom_fields["a"] = "Aa"
    sso.custom_fields["b.b"] = "B.b"
    sso
  end

  def test_parsed(parsed, sso)
    parsed.nonce.should == sso.nonce
    parsed.email.should == sso.email
    parsed.username.should == sso.username
    parsed.name.should == sso.name
    parsed.external_id.should == sso.external_id
    parsed.custom_fields["a"].should == "Aa"
    parsed.custom_fields["b.b"].should == "B.b"
  end

  it "can lookup or create user when name is blank" do
    # so we can create system messages
    Fabricate(:admin)
    sso = DiscourseSingleSignOn.new
    sso.username = "test"
    sso.name = ""
    sso.email = "test@test.com"
    sso.external_id = "A"
    user = sso.lookup_or_create_user
    user.should_not == nil
  end

  it "can fill in data on way back" do
    sso = make_sso

    url, payload = sso.to_url.split("?")
    url.should == sso.sso_url
    parsed = SingleSignOn.parse(payload, "supersecret")

    test_parsed(parsed, sso)
  end

  it "handles sso_url with query params" do
    sso = make_sso
    sso.sso_url = "http://tcdev7.wpengine.com/?action=showlogin"

    sso.to_url.split('?').size.should == 2

    url, payload = sso.to_url.split("?")
    url.should == "http://tcdev7.wpengine.com/"
    parsed = SingleSignOn.parse(payload, "supersecret")

    test_parsed(parsed, sso)
  end

  it "validates nonce" do
    _ , payload = DiscourseSingleSignOn.generate_url.split("?")

    sso = DiscourseSingleSignOn.parse(payload)
    sso.nonce_valid?.should == true

    sso.expire_nonce!

    sso.nonce_valid?.should == false

  end

  it "generates a correct sso url" do

    url, payload = DiscourseSingleSignOn.generate_url.split("?")
    url.should == @sso_url

    sso = DiscourseSingleSignOn.parse(payload)
    sso.nonce.should_not be_nil
  end
end

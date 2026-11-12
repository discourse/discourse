# frozen_string_literal: true

RSpec.describe Onebox::DomainChecker do
  describe ".is_blocked?" do
    before { SiteSetting.blocked_onebox_domains = "api.cat.org|kitten.cloud" }

    describe "returns true when entirely matched" do
      it { expect(described_class.is_blocked?("api.cat.org")).to be(true) }
      it { expect(described_class.is_blocked?("kitten.cloud")).to be(true) }
      it { expect(described_class.is_blocked?("api.dog.org")).to be(false) }
      it { expect(described_class.is_blocked?("puppy.cloud")).to be(false) }
    end

    describe "returns true when ends with .<domain>" do
      it { expect(described_class.is_blocked?("dev.api.cat.org")).to be(true) }
      it { expect(described_class.is_blocked?(".api.cat.org")).to be(true) }
      it { expect(described_class.is_blocked?("dev.kitten.cloud")).to be(true) }
      it { expect(described_class.is_blocked?(".kitten.cloud")).to be(true) }
      it { expect(described_class.is_blocked?("xapi.cat.org")).to be(false) }
      it { expect(described_class.is_blocked?("xkitten.cloud")).to be(false) }
    end

    describe "matches regardless of hostname casing" do
      it { expect(described_class.is_blocked?("API.CAT.ORG")).to be(true) }
      it { expect(described_class.is_blocked?("Api.Cat.Org")).to be(true) }
      it { expect(described_class.is_blocked?("Dev.Api.Cat.Org")).to be(true) }
      it { expect(described_class.is_blocked?("KITTEN.CLOUD")).to be(true) }
    end

    describe "matches regardless of blocked entry casing" do
      before { SiteSetting.blocked_onebox_domains = "API.CAT.ORG" }

      it { expect(described_class.is_blocked?("api.cat.org")).to be(true) }
      it { expect(described_class.is_blocked?("dev.api.cat.org")).to be(true) }
    end

    describe "matches regardless of a trailing root-label dot in the hostname" do
      it { expect(described_class.is_blocked?("api.cat.org.")).to be(true) }
      it { expect(described_class.is_blocked?("dev.api.cat.org.")).to be(true) }
      it { expect(described_class.is_blocked?("API.CAT.ORG.")).to be(true) }
      it { expect(described_class.is_blocked?("api.dog.org.")).to be(false) }
      it { expect(described_class.is_blocked?("xapi.cat.org.")).to be(false) }
    end

    describe "matches regardless of a trailing root-label dot in the blocked entry" do
      before { SiteSetting.blocked_onebox_domains = "api.cat.org." }

      it { expect(described_class.is_blocked?("api.cat.org")).to be(true) }
      it { expect(described_class.is_blocked?("dev.api.cat.org")).to be(true) }
      it { expect(described_class.is_blocked?("api.dog.org")).to be(false) }
    end

    describe "matches Unicode and punycode hostnames equivalently" do
      before { SiteSetting.blocked_onebox_domains = "exämple.com" }

      it { expect(described_class.is_blocked?("exämple.com")).to be(true) }
      it { expect(described_class.is_blocked?("xn--exmple-cua.com")).to be(true) }
      it { expect(described_class.is_blocked?("sub.exämple.com.")).to be(true) }
      it { expect(described_class.is_blocked?("other.com")).to be(false) }
    end

    describe "with an empty blocked list" do
      before { SiteSetting.blocked_onebox_domains = "" }

      it { expect(described_class.is_blocked?("api.cat.org.")).to be(false) }
    end
  end
end

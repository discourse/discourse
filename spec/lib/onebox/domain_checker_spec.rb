# frozen_string_literal: true

require "rails_helper"

describe Onebox::DomainChecker do
  describe '.is_blocked?' do
    before do
      SiteSetting.blocked_onebox_domains = "api.cat.org|kitten.cloud"
    end

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
  end
end

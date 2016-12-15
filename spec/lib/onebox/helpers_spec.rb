require 'spec_helper'

RSpec.describe Onebox::Helpers do
  describe '.blank?' do
    it { expect(Onebox::Helpers.blank?("")).to be(true) }
    it { expect(Onebox::Helpers.blank?(" ")).to be(true) }
    it { expect(Onebox::Helpers.blank?("test")).to be(false) }
    it { expect(Onebox::Helpers.blank?(["test", "testing"])).to be(false) }
    it { expect(Onebox::Helpers.blank?([])).to be(true) }
    it { expect(Onebox::Helpers.blank?({})).to be(true) }
    it { expect(Onebox::Helpers.blank?({a: 'test'})).to be(false) }
    it { expect(Onebox::Helpers.blank?(nil)).to be(true) }
    it { expect(Onebox::Helpers.blank?(true)).to be(false) }
    it { expect(Onebox::Helpers.blank?(false)).to be(true) }
  end
end

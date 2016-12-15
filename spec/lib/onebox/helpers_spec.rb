require 'spec_helper'

RSpec.describe Onebox::Helpers do
  describe '.blank?' do
    it { expect(Onebox::Helpers.blank?("")).to be(true) }
    it { expect(Onebox::Helpers.blank?("test")).to be(false) }
    it { expect(Onebox::Helpers.blank?(["test", "testing"])).to be(false) }
    it { expect(Onebox::Helpers.blank?([])).to be(true) }
  end
end

require 'rails_helper'
require 'version'

describe Discourse::VERSION do

  context "has_needed_version?" do

    it "works for major comparisons" do
      expect(Discourse.has_needed_version?('1.0.0', '1.0.0')).to eq(true)
      expect(Discourse.has_needed_version?('2.0.0', '1.0.0')).to eq(true)
      expect(Discourse.has_needed_version?('0.0.1', '1.0.0')).to eq(false)
    end

    it "works for minor comparisons" do
      expect(Discourse.has_needed_version?('1.1.0', '1.1.0')).to eq(true)
      expect(Discourse.has_needed_version?('1.2.0', '1.1.0')).to eq(true)
      expect(Discourse.has_needed_version?('2.0.0', '1.1.0')).to eq(true)
      expect(Discourse.has_needed_version?('0.1.0', '0.1.0')).to eq(true)

      expect(Discourse.has_needed_version?('1.0.0', '1.1.0')).to eq(false)
      expect(Discourse.has_needed_version?('0.0.1', '0.1.0')).to eq(false)
    end

    it "works for tiny comparisons" do
      expect(Discourse.has_needed_version?('2.0.0', '2.0.0')).to eq(true)
      expect(Discourse.has_needed_version?('2.0.1', '2.0.0')).to eq(true)
      expect(Discourse.has_needed_version?('1.12.0', '2.0.0')).to eq(false)
      expect(Discourse.has_needed_version?('1.12.0', '2.12.5')).to eq(false)
    end

    it "works for beta comparisons" do
      expect(Discourse.has_needed_version?('1.3.0.beta3', '1.2.9')).to eq(true)
      expect(Discourse.has_needed_version?('1.3.0.beta3', '1.3.0.beta1')).to eq(true)
      expect(Discourse.has_needed_version?('1.3.0.beta3', '1.3.0.beta4')).to eq(false)
      expect(Discourse.has_needed_version?('1.3.0.beta3', '1.3.0')).to eq(false)
    end

  end
end


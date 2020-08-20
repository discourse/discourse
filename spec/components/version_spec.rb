# frozen_string_literal: true

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

    it "works for beta comparisons when current_version is beta" do
      expect(Discourse.has_needed_version?('1.3.0.beta3', '1.2.9')).to eq(true)
      expect(Discourse.has_needed_version?('1.3.0.beta3', '1.3.0.beta1')).to eq(true)
      expect(Discourse.has_needed_version?('1.3.0.beta3', '1.3.0.beta4')).to eq(false)
      expect(Discourse.has_needed_version?('1.3.0.beta3', '1.3.0')).to eq(false)
    end

    it "works for beta comparisons when needed_version is beta" do
      expect(Discourse.has_needed_version?('1.2.0', '1.3.0.beta3')).to eq(false)
      expect(Discourse.has_needed_version?('1.2.9', '1.3.0.beta3')).to eq(false)
      expect(Discourse.has_needed_version?('1.3.0.beta1', '1.3.0.beta3')).to eq(false)
      expect(Discourse.has_needed_version?('1.3.0.beta4', '1.3.0.beta3')).to eq(true)
      expect(Discourse.has_needed_version?('1.3.0', '1.3.0.beta3')).to eq(true)
    end

  end

  context "compatible_resource" do
    shared_examples "test compatible resource" do
      it "returns nil when the current version is above all pinned versions" do
        expect(Discourse.find_compatible_resource(version_list, "2.6.0")).to be_nil
      end

      it "returns the correct version if matches exactly" do
        expect(Discourse.find_compatible_resource(version_list, "2.5.0.beta4")).to eq("twofivebetafour")
      end

      it "returns the closest matching version" do
        expect(Discourse.find_compatible_resource(version_list, "2.4.6.beta12")).to eq("twofivebetatwo")
      end

      it "returns the lowest version possible when using an older version" do
        expect(Discourse.find_compatible_resource(version_list, "1.4.6.beta12")).to eq("twofourtwobetaone")
      end
    end

    it "returns nil when nil" do
      expect(Discourse.find_compatible_resource(nil)).to be_nil
    end

    context "with a regular compatible list" do
      let(:version_list) { <<~VERSION_LIST
        2.5.0.beta6: twofivebetasix
        2.5.0.beta4: twofivebetafour
        2.5.0.beta2: twofivebetatwo
        2.4.4.beta6: twofourfourbetasix
        2.4.2.beta1: twofourtwobetaone
        VERSION_LIST
      }
      include_examples "test compatible resource"
    end

    context "handle a compatible resource out of order" do
      let(:version_list) { <<~VERSION_LIST
        2.4.2.beta1: twofourtwobetaone
        2.5.0.beta4: twofivebetafour
        2.5.0.beta6: twofivebetasix
        2.5.0.beta2: twofivebetatwo
        2.4.4.beta6: twofourfourbetasix
        VERSION_LIST
      }
      include_examples "test compatible resource"
    end
  end
end

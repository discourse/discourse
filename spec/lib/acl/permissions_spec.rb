# frozen_string_literal: true

RSpec.describe Acl::Permissions do
  subject(:permissions) { described_class.new(:view, :edit, :manage) }

  describe "#values" do
    it "returns the permission IDs as frozen strings in a frozen array" do
      expect(permissions.values).to eq(%w[view edit manage])
      expect(permissions.values).to be_frozen
      expect(permissions.values).to all(be_frozen)
    end
  end

  describe "named readers" do
    it "returns each permission ID as a frozen string" do
      expect([permissions.view, permissions.edit, permissions.manage]).to eq(%w[view edit manage])
      expect([permissions.view, permissions.edit, permissions.manage]).to all(be_frozen)
    end

    it "raises for an undeclared permission" do
      expect { permissions.jester }.to raise_error(NoMethodError)
    end

    it "freezes the declaration" do
      expect(permissions).to be_frozen
      expect { permissions.define_singleton_method(:view) { "Jester" } }.to raise_error(FrozenError)
    end
  end

  describe ".new" do
    it "rejects names that cannot be permission readers" do
      ["", "two words", "1view", "view-edit", "view="].each do |name|
        expect { described_class.new(name) }.to raise_error(ArgumentError)
      end
    end

    it "rejects names that conflict with existing methods" do
      %i[values class freeze to_s initialize].each do |name|
        expect { described_class.new(name) }.to raise_error(ArgumentError)
      end
    end
  end
end

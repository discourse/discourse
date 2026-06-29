# frozen_string_literal: true

RSpec.describe AclTarget do
  let(:target_class) do
    Class.new(ActiveRecord::Base) do
      include AclTarget

      self.table_name = "posts"

      def self.name
        "AclTargetSpecTarget"
      end
    end
  end

  it "adds mandatory acl class methods" do
    expect(target_class).to respond_to(:has_mandatory_acl?, :acl_is_mandatory?)
  end

  it "registers loaded target classes" do
    expect(described_class.target_classes).to include(target_class)
  end

  describe ".acl_target_key" do
    it "returns the class name" do
      expect(target_class.acl_target_key).to eq("AclTargetSpecTarget")
    end
  end

  describe ".has_mandatory_acl?" do
    it "returns false without mandatory acl entries" do
      expect(target_class).not_to have_mandatory_acl

      target_class.define_singleton_method(:mandatory_acl) { [] }

      expect(target_class).not_to have_mandatory_acl
    end

    it "returns true with mandatory acl entries" do
      target_class.define_singleton_method(:mandatory_acl) do
        [{ type: :group, id: 1, permission: "view" }]
      end

      expect(target_class).to have_mandatory_acl
    end
  end

  describe ".acl_is_mandatory?" do
    before do
      target_class.define_singleton_method(:mandatory_acl) do
        [{ type: :group, id: 1, permission: "view" }, { type: :user, id: 2, permission: "edit" }]
      end
    end

    it "returns true for matching mandatory acl entries" do
      expect(target_class.acl_is_mandatory?({ type: :group, id: 1, permission: "view" })).to eq(
        true,
      )
    end

    it "returns false for different acl entries" do
      expect(target_class.acl_is_mandatory?({ type: :group, id: 1, permission: "edit" })).to eq(
        false,
      )
    end
  end
end

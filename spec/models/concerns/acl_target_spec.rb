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

  around do |example|
    stub_const(target_class, :ACL_PERMISSIONS, Acl::Permissions.new(:view, :edit)) { example.run }
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

  describe "permission scopes" do
    fab!(:acl_user, :user)
    fab!(:owned_post, :post)
    fab!(:viewable_post, :post)
    fab!(:other_post, :post)

    before do
      Fabricate(
        :access_control_list_with_users,
        target: owned_post.becomes(target_class),
        permission: "owner",
        users: [acl_user],
      )
      Fabricate(
        :access_control_list_with_users,
        target: viewable_post.becomes(target_class),
        permission: "view",
        users: [acl_user],
      )
    end

    it "includes owned targets in a single-permission scope" do
      expect(target_class.with_acl_permission(acl_user.guardian, "view").pluck(:id)).to(
        contain_exactly(owned_post.id, viewable_post.id),
      )
    end

    it "includes owned targets in a multi-permission scope" do
      expect(
        target_class.with_any_acl_permissions(acl_user.guardian, %w[view edit]).pluck(:id),
      ).to contain_exactly(owned_post.id, viewable_post.id)
    end
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::AccessControlParameter do
  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:group)
    fab!(:other_group, :group)

    let(:params) { { value: } }
    let(:options) { {} }
    let(:dependencies) { { resolver: expression_resolver } }
    let(:sandbox) { DiscourseWorkflows::JsSandbox.new({}) }
    let(:expression_resolver) { DiscourseWorkflows::ExpressionResolver.new({}, sandbox:) }
    let(:entries) { [{ type: "group", id: group.id, permission: "view" }] }
    let(:value) { { entries:, group_ids: [other_group.id], permission: "edit" } }

    after do
      expression_resolver.dispose
      sandbox.dispose
    end

    it "combines fixed entries and input groups with their selected permissions" do
      expect(result).to run_successfully
      expect(result[:acl].map(&:symbolize_keys)).to eq(
        entries + [{ type: "group", id: other_group.id, permission: "edit" }],
      )
    end

    it "keeps fixed permissions when input groups overlap and removes duplicates" do
      value[:entries] = entries * 2
      value[:group_ids] = [group.id, other_group.id, other_group.id]

      expect(result).to run_successfully
      expect(result[:acl].map(&:symbolize_keys)).to eq(
        entries + [{ type: "group", id: other_group.id, permission: "edit" }],
      )
    end

    it "accepts saved arrays including the system user and everyone group" do
      params[:value] = [
        { type: "user", id: Discourse::SYSTEM_USER_ID, permission: "edit" },
        { type: "group", id: Group::AUTO_GROUPS[:everyone], permission: "view" },
      ]

      expect(result).to run_successfully
      expect(result[:acl].map(&:symbolize_keys)).to eq(params[:value])
    end

    it "passes through custom permissions without an allowlist option" do
      entries.first[:permission] = "manage"
      value[:permission] = "manage"

      expect(result).to run_successfully
      expect(result[:acl].map(&:symbolize_keys)).to eq(
        entries + [{ type: "group", id: other_group.id, permission: "manage" }],
      )
    end

    it "ignores the shared permission when group input is absent" do
      value[:group_ids] = ""
      value[:permission] = nil

      expect(result).to run_successfully
      expect(result[:acl].map(&:symbolize_keys)).to eq(entries)
    end

    it "accepts an empty input array" do
      value[:group_ids] = []

      expect(result).to run_successfully
      expect(result[:acl].map(&:symbolize_keys)).to eq(entries)
    end

    it "rejects input IDs that are strings" do
      value[:group_ids] = [other_group.id.to_s]

      expect(result).to fail_a_policy(:valid_group_ids)
    end

    it "rejects input groups that no longer exist" do
      other_group.destroy!

      expect(result).to fail_a_policy(:groups_exist)
    end

    it "checks required permissions against the resolved ACL" do
      options[:required_permissions] = ["edit"]
      value[:group_ids] = []

      expect(result).to fail_a_policy(:required_permissions_present)
    end

    it "allows a required permission supplied by input groups" do
      options[:required_permissions] = ["edit"]

      expect(result).to run_successfully
      expect(result[:acl].map(&:symbolize_keys)).to eq(
        entries + [{ type: "group", id: other_group.id, permission: "edit" }],
      )
    end

    it "counts mandatory permissions without adding them to the returned ACL" do
      target_class =
        Class.new do
          def self.has_mandatory_acl?
            true
          end

          def self.mandatory_acl
            [{ type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" }]
          end
        end
      options.merge!(required_permissions: ["manage"], acl_target_type: "WorkflowAclTarget")
      value[:group_ids] = ""

      stub_const(Object, :WorkflowAclTarget, target_class) do
        expect(result).to run_successfully
        expect(result[:acl].map(&:symbolize_keys)).to eq(entries)
      end
    end
  end
end

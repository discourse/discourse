# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowSettingField::UpdateValue do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:setting_field_id) }

    it do
      is_expected.to validate_length_of(:value).is_at_most(
        DiscourseWorkflows::WorkflowSettingField::UpdateValue::MAX_VALUE_LENGTH,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
    fab!(:setting_field) do
      Fabricate(
        :discourse_workflows_workflow_setting_field,
        workflow:,
        key: "priority",
        label: "Priority",
        field_type: "enum",
        type_options: {
          "choices" => %w[low medium high],
        },
      )
    end

    let(:params) do
      { workflow_id: workflow.id, setting_field_id: setting_field.id, value: "medium" }
    end
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the workflow does not exist" do
      let(:params) { super().merge(workflow_id: -1) }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the setting field does not exist" do
      let(:params) { super().merge(setting_field_id: -1) }

      it { is_expected.to fail_to_find_a_model(:workflow_setting_field) }
    end

    context "when the value is not one of the enum's choices" do
      let(:params) { super().merge(value: "extreme") }

      it { is_expected.to fail_a_policy(:value_is_valid) }
    end

    context "when the field is a boolean and the value isn't true/false" do
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "enabled",
          label: "Enabled",
          field_type: "boolean",
        )
      end

      let(:params) { super().merge(value: "yes") }

      it { is_expected.to fail_a_policy(:value_is_valid) }
    end

    context "when the field is a category_list and the id doesn't exist" do
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "cats",
          label: "Cats",
          field_type: "category_list",
        )
      end

      let(:params) { super().merge(value: "999999") }

      it { is_expected.to fail_a_policy(:value_is_valid) }
    end

    context "when the field is a category_list and the id exists" do
      fab!(:category)
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "cats",
          label: "Cats",
          field_type: "category_list",
        )
      end

      let(:params) { super().merge(value: category.id.to_s) }

      it { is_expected.to run_successfully }
    end

    context "when the field is a category and the id doesn't exist" do
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "cat",
          label: "Cat",
          field_type: "category",
        )
      end

      let(:params) { super().merge(value: "999999") }

      it { is_expected.to fail_a_policy(:value_is_valid) }
    end

    context "when the field is a category and the id exists" do
      fab!(:category)
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "cat",
          label: "Cat",
          field_type: "category",
        )
      end

      let(:params) { super().merge(value: category.id.to_s) }

      it { is_expected.to run_successfully }
    end

    context "when the field is a group and the id doesn't exist" do
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "grp",
          label: "Group",
          field_type: "group",
        )
      end

      let(:params) { super().merge(value: "999999") }

      it { is_expected.to fail_a_policy(:value_is_valid) }
    end

    context "when the field is a group and the id exists" do
      fab!(:group)
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "grp",
          label: "Group",
          field_type: "group",
        )
      end

      let(:params) { super().merge(value: group.id.to_s) }

      it { is_expected.to run_successfully }
    end

    context "when clearing the value" do
      let(:params) { super().merge(value: nil) }

      it { is_expected.to run_successfully }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "updates the value" do
        expect { result }.to change { setting_field.reload.value }.to("medium")
      end

      it "always creates a new workflow version, even when unpublished" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
      end

      it "embeds the new value in the version snapshot" do
        result
        new_version = workflow.reload.workflow_versions.find_by(version_id: workflow.version_id)
        entry = new_version.setting_schema.find { |f| f["key"] == "priority" }
        expect(entry["value"]).to eq("medium")
      end

      it "indexes workflow dependencies for the new version" do
        error_workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
        workflow.update!(error_workflow_id: error_workflow.id)

        expect(result).to run_successfully

        dependency =
          DiscourseWorkflows::WorkflowDependency.find_by(
            workflow_version_id: result.workflow_version.version_id,
            dependency_type: "error_workflow",
          )
        expect(dependency).to be_present
        expect(dependency.dependency_key).to eq(error_workflow.id.to_s)
      end

      it_behaves_like "expires workflow caches"
    end

    context "when the workflow has never been published" do
      it "snapshots but does not publish" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
        expect(workflow.published?).to eq(false)
        expect(workflow.active_version_id).to be_nil
      end
    end

    context "when the workflow is published and the draft was clean" do
      fab!(:workflow) do
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true)
      end
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "priority",
          label: "Priority",
          field_type: "enum",
          type_options: {
            "choices" => %w[low medium high],
          },
        )
      end

      it "auto-publishes the value immediately" do
        result
        workflow.reload
        expect(workflow.active_version_id).to eq(workflow.version_id)
        expect(workflow.has_unpublished_changes?).to eq(false)
      end

      it "re-pins the workflow's production webhook to the newly auto-published version" do
        graph =
          build_workflow_graph do |g|
            g.node "webhook-1",
                   "trigger:webhook",
                   configuration: {
                     "path" => "priority-hook",
                     "http_method" => "POST",
                   }
          end
        workflow.update!(nodes: graph[:nodes], connections: graph[:connections])
        workflow.snapshot!(user: admin)
        workflow.publish!(user: admin)
        published_version_id = workflow.active_version_id

        result

        webhook_row = DiscourseWorkflows::Webhook.production.find_by(workflow_id: workflow.id)
        expect(webhook_row.workflow_version_id).to eq(workflow.reload.active_version_id)
        expect(webhook_row.workflow_version_id).not_to eq(published_version_id)
      end

      it_behaves_like "expires workflow caches"

      context "when another active workflow already owns the same webhook route" do
        before do
          graph =
            build_workflow_graph do |g|
              g.node "webhook-1",
                     "trigger:webhook",
                     configuration: {
                       "path" => "shared-hook",
                       "http_method" => "POST",
                     }
            end
          owner =
            Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
          version = owner.workflow_versions.find_by(version_id: owner.version_id)
          DiscourseWorkflows::Webhook::Action::ActivateWebhooks.call(
            workflow: owner,
            workflow_version: version,
          )

          conflicting_graph =
            build_workflow_graph do |g|
              g.node "webhook-1",
                     "trigger:webhook",
                     configuration: {
                       "path" => "shared-hook",
                       "http_method" => "POST",
                     }
            end
          workflow.update!(
            nodes: conflicting_graph[:nodes],
            connections: conflicting_graph[:connections],
          )
          workflow.snapshot!(user: admin)
          workflow.publish!(user: admin)
        end

        it { is_expected.to fail_a_step(:activate_triggers) }

        it "still saves the value as a draft, without publishing it" do
          published_version_id = workflow.active_version_id

          result

          expect(setting_field.reload.value).to eq("medium")
          expect(workflow.reload.active_version_id).to eq(published_version_id)
          expect(workflow.has_unpublished_changes?).to eq(true)
        end
      end
    end

    context "when the workflow is published but has other pending changes" do
      fab!(:workflow) do
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true)
      end
      fab!(:setting_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "priority",
          label: "Priority",
          field_type: "enum",
          type_options: {
            "choices" => %w[low medium high],
          },
        )
      end

      it "snapshots the value but does not auto-publish" do
        published_version_id = workflow.active_version_id
        workflow.update!(name: "#{workflow.name} (draft edit)")
        workflow.snapshot!(user: admin)

        expect { result }.to change { workflow.reload.version_counter }
        expect(workflow.reload.active_version_id).to eq(published_version_id)
        expect(workflow.has_unpublished_changes?).to eq(true)
      end
    end
  end
end

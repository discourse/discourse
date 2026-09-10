import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import SiteSetting from "discourse/admin/models/site-setting";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";
import TimezoneInput from "discourse/select-kit/components/timezone-input";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import ErrorWorkflowChooser from "./error-workflow-chooser";
import InUseDialog from "./in-use-dialog";
import WorkflowSettingFieldList from "./setting-field-list";
import SettingsPublishNotice from "./settings-publish-notice";

const FIELD_TYPE_TO_SITE_SETTING_TYPE = {
  string: { type: "string" },
  integer: { type: "integer" },
  boolean: { type: "bool" },
  enum: { type: "enum" },
  category: { type: "category" },
  category_list: { type: "list", list_type: "category" },
  group: { type: "group" },
  group_list: { type: "list", list_type: "group" },
  tag_list: { type: "list", list_type: "tag" },
  simple_list: { type: "simple_list" },
};

// trackChanges = false keeps these rows out of the global unsaved-changes
// banner used by the real site settings page, since they aren't site settings.
class WorkflowSettingFieldRow extends SiteSettingComponent {
  @service toasts;

  trackChanges = false;

  // These rows have no "default" concept to compare against (buildFieldSetting
  // always sets default: ""), so the inherited overridden/reset UI is meaningless.
  get groupedOverridden() {
    return false;
  }

  get overridden() {
    return false;
  }

  get staffLogFilter() {
    return null;
  }

  async _save(settings) {
    const setting = settings[0];
    const wasPublished = Boolean(setting.workflow.activeVersionId);

    const response = await ajax(
      `/admin/plugins/discourse-workflows/workflows/${setting.workflow.id}/setting-fields/${setting.workflowSettingFieldId}/value.json`,
      { type: "PUT", data: { value: setting.buffered.get("value") } }
    );

    // Mutated in place (not reassigned) so other rows' @cached SiteSetting
    // wrappers aren't rebuilt, discarding their own in-progress edits.
    const savedField = setting.workflow.settingFields.find(
      (field) => field.id === setting.workflowSettingFieldId
    );
    if (savedField) {
      Object.assign(savedField, response.workflow_setting_field);
    }

    setting.workflow.setProperties({
      versionId: response.workflow.version_id,
      activeVersionId: response.workflow.active_version_id,
      hasUnpublishedChanges: response.workflow.has_unpublished_changes,
    });

    if (
      wasPublished &&
      response.workflow.active_version_id &&
      !response.workflow.has_unpublished_changes
    ) {
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("discourse_workflows.settings.fields.value_published"),
        },
      });
    }

    return response;
  }
}

function buildFieldSetting(field, workflow) {
  const { type, list_type } =
    FIELD_TYPE_TO_SITE_SETTING_TYPE[field.field_type] ??
    FIELD_TYPE_TO_SITE_SETTING_TYPE.string;

  return SiteSetting.create({
    setting: field.key,
    humanized_name: field.label,
    description: escapeExpression(field.description),
    type,
    list_type,
    valid_values: field.type_options?.choices,
    value: field.value ?? "",
    default: "",
    workflow,
    workflowSettingFieldId: field.id,
  });
}

export default class WorkflowSettings extends Component {
  @service router;
  @service dialog;
  @service toasts;

  formData = {
    errorWorkflowId: this.args.workflow.errorWorkflowId,
    timezone: this.args.workflow.timezone || "UTC",
  };

  errorWorkflowContent =
    this.args.workflow.errorWorkflowId && this.args.workflow.errorWorkflowName
      ? [
          {
            id: this.args.workflow.errorWorkflowId,
            name: this.args.workflow.errorWorkflowName,
          },
        ]
      : [];

  get fieldsDescription() {
    const workflow = this.args.workflow;
    const willAutoPublish =
      Boolean(workflow.activeVersionId) && !workflow.hasUnpublishedChanges;

    return i18n(
      willAutoPublish
        ? "discourse_workflows.settings.fields.description_will_publish"
        : "discourse_workflows.settings.fields.description_will_draft"
    );
  }

  @cached
  get fieldSettings() {
    return this.args.workflow.settingFields.map((field) =>
      buildFieldSetting(field, this.args.workflow)
    );
  }

  @action
  async deleteWorkflow() {
    await this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.delete_confirm", {
        name: this.args.workflow.name,
      }),
      didConfirm: async () => {
        try {
          await this.args.workflow.destroyRecord();
          this.router.transitionTo(
            "adminPlugins.show.discourse-workflows.index"
          );
        } catch (e) {
          const body = e.jqXHR?.responseJSON;
          if (body?.type === "workflow_called_by_other_workflows") {
            this.dialog.alert({
              title: i18n("discourse_workflows.in_use_title"),
              bodyComponent: InUseDialog,
              bodyComponentModel: {
                description: i18n("discourse_workflows.in_use_description"),
                workflows: body.referencing_workflows,
                close: () => this.dialog.cancel(),
              },
            });
          } else {
            popupAjaxError(e);
          }
        }
      },
    });
  }

  @action
  async submitForm(name, value, data) {
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}.json`,
        {
          type: "PUT",
          data: {
            workflow: {
              error_workflow_id: data.errorWorkflowId,
              timezone: data.timezone,
            },
          },
        }
      );

      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_workflows.settings.saved") },
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <SettingsPublishNotice @workflow={{@workflow}} />

    <DPageSubheader
      @descriptionLabel={{this.fieldsDescription}}
      @titleLabel={{i18n "discourse_workflows.settings.fields.title"}}
    />

    <section class="form-horizontal settings workflows-settings__field-values">
      {{#each this.fieldSettings as |setting|}}
        <WorkflowSettingFieldRow @setting={{setting}} />
      {{/each}}
    </section>

    <WorkflowSettingFieldList @workflow={{@workflow}} />

    <Form
      class="workflows-settings"
      @data={{this.formData}}
      @onSet={{this.submitForm}}
      as |form|
    >
      <form.Field
        @description={{i18n
          "discourse_workflows.settings.error_workflow_description"
        }}
        @format="full"
        @name="errorWorkflowId"
        @title={{i18n "discourse_workflows.settings.error_workflow"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <ErrorWorkflowChooser
            @content={{this.errorWorkflowContent}}
            @onChange={{field.set}}
            @options={{hash
              none="discourse_workflows.settings.error_workflow_none"
              excludeWorkflowId=@workflow.id
            }}
            @value={{field.value}}
          />
        </field.Control>
      </form.Field>

      <form.Field
        @description={{i18n
          "discourse_workflows.settings.timezone_description"
        }}
        @format="full"
        @name="timezone"
        @title={{i18n "discourse_workflows.settings.timezone"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <TimezoneInput @onChange={{field.set}} @value={{field.value}} />
        </field.Control>
      </form.Field>

      <form.Emphasis
        @subtitle={{i18n "discourse_workflows.settings.delete_description"}}
        @title={{i18n "discourse_workflows.settings.danger_zone"}}
        @type="error"
      >
        <form.Actions>
          <form.Button
            class="btn-danger"
            @action={{this.deleteWorkflow}}
            @label="discourse_workflows.delete"
          />
        </form.Actions>
      </form.Emphasis>
    </Form>
  </template>
}

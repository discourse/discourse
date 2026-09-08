import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DAccessControlField from "discourse/ui-kit/d-access-control-field";
import { i18n } from "discourse-i18n";
import {
  fieldShowDescription,
  isExpression,
  propertyDescription,
} from "../../../lib/workflows/property-engine";
import AccessControlListInput, {
  accessControlValue,
} from "./access-control-list-input";

// TODO (martin) See if anything can be improved/simplified here.
// This is what is used by the workflow editor to render an ACL field. It is a
// wrapper around DAccessControlField that is added via fieldComponent, for
// kanban boards this might e.g. be BoardsAccessControlField.
export default class AccessControlListControl extends Component {
  @service site;

  get aclTarget() {
    const options = this.args.schema.control_options || {};
    return {
      type: options.acl_target_type,
      key: options.acl_target_key,
      name: options.acl_target_name
        ? i18n(options.acl_target_name)
        : this.args.label,
    };
  }

  get description() {
    if (fieldShowDescription(this.args.schema)) {
      return propertyDescription(this.args.nodeDefinition, this.args.fieldName);
    }
  }

  get fieldComponent() {
    return this.args.fieldComponent ?? DAccessControlField;
  }

  get permissions() {
    return this.args.schema.control_options?.permissions || ["view", "edit"];
  }

  get requiredPermissions() {
    return this.args.schema.control_options?.required_permissions;
  }

  get supportsGroupInput() {
    return this.args.schema.control_options?.groups_from_input;
  }

  get validation() {
    return this.args.schema.required ? "required" : undefined;
  }

  // TODO (martin) Investigate this deeper, seems kinda complex.
  @action
  validateConfiguration(name, value, { addError }) {
    const config = accessControlValue(value);
    const groups = config.group_ids;
    const hasInput = groups !== undefined && groups !== null && groups !== "";
    const dynamic = isExpression(groups);
    const error = (message) =>
      addError(name, { title: this.args.label, message });

    if (
      hasInput &&
      !dynamic &&
      (!Array.isArray(groups) ||
        !groups.every((id) => Number.isInteger(id) && id >= 0))
    ) {
      error(i18n("discourse_workflows.access_control.invalid_input"));
    }
    if (hasInput && !this.permissions.includes(config.permission)) {
      error(i18n("discourse_workflows.access_control.invalid_permission"));
    }
    const mandatory =
      this.site.access_control?.mandatory_acl?.[
        this.aclTarget.key ?? this.aclTarget.type
      ] || [];
    const entries = [...(config.entries || []), ...mandatory];
    if (hasInput && (dynamic || groups.length)) {
      entries.push({ permission: config.permission });
    }
    if (
      this.requiredPermissions?.length &&
      !entries.some((entry) =>
        this.requiredPermissions.includes(entry.permission)
      )
    ) {
      error(
        i18n("access_control.manage.required_permission_not_added", {
          permission: this.requiredPermissions.join(", "),
          typeName: this.aclTarget.name,
        })
      );
    }
  }

  <template>
    {{#if this.supportsGroupInput}}
      <@form.Field
        @description={{this.description}}
        @format="max"
        @name={{@fieldName}}
        @onSet={{@onSet}}
        @showOptional={{@showOptional}}
        @title={{@label}}
        @type="custom"
        @validate={{this.validateConfiguration}}
        @validation={{this.validation}}
        as |field|
      >
        <field.Control>
          <AccessControlListInput
            @aclTarget={{this.aclTarget}}
            @field={{field}}
            @permissions={{this.permissions}}
            @session={{@session}}
            @transformPermissionOptions={{@transformPermissionOptions}}
          />
        </field.Control>
      </@form.Field>
    {{else}}
      <this.fieldComponent
        @aclTarget={{this.aclTarget}}
        @description={{this.description}}
        @form={{@form}}
        @mustHavePermissions={{this.requiredPermissions}}
        @name={{@fieldName}}
        @onSet={{@onSet}}
        @showOptional={{@showOptional}}
        @title={{@label}}
        @validation={{this.validation}}
      />
    {{/if}}
  </template>
}

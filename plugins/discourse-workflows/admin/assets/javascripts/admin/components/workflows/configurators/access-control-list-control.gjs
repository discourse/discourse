import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKOptional from "discourse/form-kit/components/fk/optional";
import DAccessControl, {
  defaultPermissions,
} from "discourse/ui-kit/d-access-control";
import DAccessControlPermissionMenu from "discourse/ui-kit/d-access-control-permission-menu";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";
import {
  fieldShowDescription,
  isExpression,
  propertyDescription,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

const GROUP_SCHEMA = { type: "array" };

function accessControlValue(value) {
  return Array.isArray(value) || !value
    ? { entries: value || [], group_ids: "", permission: "view" }
    : { entries: [], group_ids: "", permission: "view", ...value };
}

function plainGroupIds(value) {
  return Array.isArray(value) ? JSON.stringify(value) : value;
}

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

  get permissionOptions() {
    const options =
      this.args.transformPermissionOptions?.(defaultPermissions()) ||
      defaultPermissions();
    return options.filter((option) => this.permissions.includes(option.id));
  }

  get permissions() {
    return this.args.schema.control_options?.permissions || ["view", "edit"];
  }

  get requiredPermissions() {
    return this.args.schema.control_options?.required_permissions;
  }

  get validation() {
    return this.args.schema.required ? "required" : undefined;
  }

  @action
  setEntries(field, entries) {
    field.set({ ...accessControlValue(field.value), entries });
  }

  @action
  setGroupIds(field, group_ids) {
    field.set({ ...accessControlValue(field.value), group_ids });
  }

  @action
  setPlainGroupIds(field, event) {
    const value = event.target.value;
    let parsed = value;
    try {
      parsed = JSON.parse(value);
    } catch {
      // Keep incomplete input editable until validation.
    }
    this.setGroupIds(field, parsed);
  }

  @action
  setPermission(field, permission) {
    field.set({ ...accessControlValue(field.value), permission });
  }

  // Checks whether the ACL settings are valid before the form can be saved:
  //
  // - Group IDs: If you enter a literal value, it must be an array of
  // non-negative whole numbers, such as [12, 34]. Expressions are checked
  // later, when the workflow runs.
  // - If group input is supplied, its selected permission must be
  // allowed by the node (e.g. for Boards, only Viewer/Editor/Manager)
  // - Checks the fixed entries, mandatory entries, and
  // input-group permission for any required permission. For e.g. Boards, there must
  // be a Manager.
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
        {{#let (accessControlValue field.value) as |config|}}
          <div class="workflows-access-control">
            <DAccessControl
              @acl={{config.entries}}
              @aclTarget={{this.aclTarget}}
              @groups={{this.site.groups}}
              @onChange={{fn this.setEntries field}}
              @transformPermissionOptions={{@transformPermissionOptions}}
            >
              <:additionalRows>
                <div
                  class="d-access-control__row workflows-access-control__input-row"
                >
                  <div class="workflows-access-control__groups">
                    <FKLabel
                      class="form-kit__container-title"
                      @fieldId="{{field.id}}-groups"
                    >
                      <span>{{i18n
                          "discourse_workflows.access_control.groups_from_input"
                        }}</span>
                      <FKOptional />
                    </FKLabel>
                    <ExpressionWrapper
                      @field={{hash
                        value=config.group_ids
                        set=(fn this.setGroupIds field)
                      }}
                      @inputId="{{field.id}}-groups"
                      @inputLabel={{i18n
                        "discourse_workflows.access_control.groups_from_input"
                      }}
                      @placeholder={{i18n
                        "discourse_workflows.access_control.input_placeholder"
                      }}
                      @schema={{GROUP_SCHEMA}}
                      @session={{@session}}
                      @supportsExpression={{true}}
                    >
                      <DTextField
                        id="{{field.id}}-groups"
                        @placeholder={{i18n
                          "discourse_workflows.access_control.input_placeholder"
                        }}
                        @value={{plainGroupIds config.group_ids}}
                        {{on "input" (fn this.setPlainGroupIds field)}}
                      />
                    </ExpressionWrapper>
                  </div>
                  <div class="workflows-access-control__permission">
                    <DAccessControlPermissionMenu
                      id="{{field.id}}-permission"
                      @onChange={{fn this.setPermission field}}
                      @options={{this.permissionOptions}}
                      @value={{config.permission}}
                    />
                  </div>
                </div>
              </:additionalRows>
            </DAccessControl>
          </div>
        {{/let}}
      </field.Control>
    </@form.Field>
  </template>
}

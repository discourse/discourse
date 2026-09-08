import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKOptional from "discourse/form-kit/components/fk/optional";
import DAccessControl, {
  defaultPermissions,
} from "discourse/ui-kit/d-access-control";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";
import ExpressionWrapper from "./expression-wrapper";

const GROUP_SCHEMA = { type: "array" };

export function accessControlValue(value) {
  return Array.isArray(value) || !value
    ? { entries: value || [], group_ids: "", permission: "view" }
    : { entries: [], group_ids: "", permission: "view", ...value };
}

// TODO (martin) Might rename this, its a bit generic...this is what is used
// when the AccessControlListControl component supports adding additional
// groups via input...IDK if this needs to be optional or if it can always
// use this.
//
// Also not sure why DAccessControlField is not used here...
export default class AccessControlListInput extends Component {
  @service site;

  get groupField() {
    return { value: this.value.group_ids, set: this.setGroupIds };
  }

  get permissionOptions() {
    const options =
      this.args.transformPermissionOptions?.(defaultPermissions()) ||
      defaultPermissions();
    return options.filter((option) =>
      (this.args.permissions || ["view", "edit"]).includes(option.id)
    );
  }

  get plainGroupIds() {
    return Array.isArray(this.value.group_ids)
      ? JSON.stringify(this.value.group_ids)
      : this.value.group_ids;
  }

  get value() {
    return accessControlValue(this.args.field.value);
  }

  @action
  setEntries(entries) {
    this.args.field.set({ ...this.value, entries });
  }

  @action
  setGroupIds(group_ids) {
    this.args.field.set({ ...this.value, group_ids });
  }

  @action
  setPlainGroupIds(event) {
    const value = event.target.value;
    let parsed = value;
    try {
      parsed = JSON.parse(value);
    } catch {
      // Keep incomplete input editable until validation.
    }
    this.setGroupIds(parsed);
  }

  @action
  setPermission(permission) {
    this.args.field.set({ ...this.value, permission });
  }

  <template>
    <div class="workflows-access-control">
      <DAccessControl
        @acl={{this.value.entries}}
        @aclTarget={{@aclTarget}}
        @groups={{this.site.groups}}
        @onChange={{this.setEntries}}
        @transformPermissionOptions={{@transformPermissionOptions}}
      />
      <div class="workflows-access-control__input-row">
        <div class="workflows-access-control__groups">
          <FKLabel
            class="form-kit__container-title"
            @fieldId="{{@field.id}}-groups"
          >
            <span>{{i18n
                "discourse_workflows.access_control.groups_from_input"
              }}</span>
            <FKOptional />
          </FKLabel>
          <ExpressionWrapper
            @inputId="{{@field.id}}-groups"
            @inputLabel={{i18n
              "discourse_workflows.access_control.groups_from_input"
            }}
            @field={{this.groupField}}
            @placeholder={{i18n
              "discourse_workflows.access_control.input_placeholder"
            }}
            @schema={{GROUP_SCHEMA}}
            @session={{@session}}
            @supportsExpression={{true}}
          >
            <DTextField
              id="{{@field.id}}-groups"
              @placeholder={{i18n
                "discourse_workflows.access_control.input_placeholder"
              }}
              @value={{readonly this.plainGroupIds}}
              {{on "input" this.setPlainGroupIds}}
            />
          </ExpressionWrapper>
        </div>
        <div class="workflows-access-control__permission">
          <FKLabel
            class="form-kit__container-title"
            @fieldId="{{@field.id}}-permission"
          >
            <span>{{i18n
                "discourse_workflows.access_control.permission"
              }}</span>
          </FKLabel>
          <DNativeSelect
            id="{{@field.id}}-permission"
            @includeNone={{false}}
            @onChange={{this.setPermission}}
            @value={{this.value.permission}}
            as |select|
          >
            {{#each this.permissionOptions as |option|}}
              <select.Option
                @value={{option.id}}
              >{{option.name}}</select.Option>
            {{/each}}
          </DNativeSelect>
        </div>
      </div>
    </div>
  </template>
}

import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DAccessControl from "discourse/ui-kit/d-access-control";
import { i18n } from "discourse-i18n";

export default class DAccessControlField extends Component {
  @service site;
  @service dialog;

  @action
  async validateAccess(name, value, { addError, preventSubmit }) {
    const acl = value || [];

    if (this.args.mustHavePermissions) {
      if (
        !acl.some((entry) =>
          this.args.mustHavePermissions.includes(entry.permission)
        )
      ) {
        addError(name, {
          title: this.args.title,
          message: i18n("access_control.manage.required_permission_not_added", {
            permission: this.args.mustHavePermissions.join(", "),
            typeName: this.args.aclTarget.name,
          }),
        });
      }
    }

    let evaluation = {};

    try {
      await ajax("/access-control/evaluate.json", {
        type: "POST",
        contentType: "application/json",
        data: JSON.stringify({
          target_type: this.args.aclTarget.type,
          target_id: this.args.aclTarget.id,
          new_acl: acl,
        }),
      });
    } catch (err) {
      if (
        !Object.hasOwn(
          err.jqXHR.responseJSON.extras,
          "current_user_will_lose_permission"
        )
      ) {
        addError(name, {
          title: this.args.title,
          message: i18n("generic_error"),
        });
        return;
      } else {
        // extras is where we store current_user_will_lose_permission and loss_warning_permissions
        Object.assign(evaluation, err.jqXHR.responseJSON.extras);
        evaluation.errorMessage = err.jqXHR.responseJSON.errors[0];
      }
    }

    if (!evaluation.current_user_will_lose_permission) {
      return;
    }

    const confirmed = await this.dialog.confirm({
      message: evaluation.errorMessage,
    });

    if (!confirmed) {
      preventSubmit();
      return;
    }

    this.args.onAccessLossConfirmed?.({
      permissions: evaluation.loss_warning_permissions ?? [],
    });
  }

  <template>
    <@form.Field
      @name="acl"
      @title={{@title}}
      @description={{@description}}
      @format="max"
      @type="custom"
      @validate={{this.validateAccess}}
      as |field|
    >
      <field.Control>
        <DAccessControl
          @groups={{this.site.groups}}
          @acl={{field.value}}
          @aclTarget={{@aclTarget}}
          @onChange={{@onChange}}
          @transformPermissionOptions={{@transformPermissionOptions}}
        />
      </field.Control>
    </@form.Field>
  </template>
}

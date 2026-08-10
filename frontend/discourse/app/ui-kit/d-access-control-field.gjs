import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DAccessControl from "discourse/ui-kit/d-access-control";
import { i18n } from "discourse-i18n";

export default class DAccessControlField extends Component {
  @service site;
  @service dialog;

  @tracked confirmedAclFingerprint = null;

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

    const fingerprint = JSON.stringify(acl);

    // The user already confirmed this exact proposed ACL.
    if (this.confirmedAclFingerprint === fingerprint) {
      return;
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
        Object.assign(evaluation, err.jqXHR.responseJSON.extras);
        evaluation.errorMessage = err.jqXHR.responseJSON.errors[0];
      }
    }

    if (!evaluation.current_user_will_lose_permission) {
      return;
    }

    // TODO (martin) Do we want to show a specific message based on "downgrade" e.g. you will no longerbe able
    // to manage but you can still view?
    //
    // Yes...if loss_warning_permissions is present/not empty we should reload after modal closes.
    const confirmed = await this.dialog.confirm({
      message: evaluation.errorMessage,
    });

    if (confirmed) {
      // TODO (martin) Not even sure we need this? If you confirm then we save, and whatever
      // form generally goes away ...
      this.confirmedAclFingerprint = fingerprint;
      // TODO (martin) Do we need to reload the page or something here? E.g. what happens
      // if the  permission for even being able to view this thing disappears?
    } else {
      preventSubmit();
    }
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

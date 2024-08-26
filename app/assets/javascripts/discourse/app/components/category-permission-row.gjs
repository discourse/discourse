import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import PermissionType from "discourse/models/permission-type";
import dIcon from "discourse-common/helpers/d-icon";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

const EVERYONE = "everyone";

export default class CategoryPermissionRow extends Component {
  @service currentUser;

  get everyonePermissionType() {
    return this.args.everyonePermission.permission_type;
  }

  get canReply() {
    return (
      this.args.type === PermissionType.CREATE_POST ||
      this.args.type === PermissionType.FULL
    );
  }

  get canCreate() {
    return this.args.type === PermissionType.FULL;
  }

  get canCreateIcon() {
    return this.canCreate ? "check-square" : "far-square";
  }

  get canReplyIcon() {
    return this.canReply ? "check-square" : "far-square";
  }

  get replyGranted() {
    return this.args.type <= PermissionType.CREATE_POST ? "reply-granted" : "";
  }

  get createGranted() {
    return this.args.type === PermissionType.FULL ? "create-granted" : "";
  }

  get isEveryoneGroup() {
    return this.args.groupName === EVERYONE;
  }

  get replyDisabled() {
    if (
      !this.isEveryoneGroup &&
      this.everyonePermissionType &&
      this.everyonePermissionType <= PermissionType.CREATE_POST
    ) {
      return true;
    }
    return false;
  }

  get replyTooltip() {
    return this.replyDisabled
      ? I18n.t("category.permissions.inherited")
      : I18n.t("category.permissions.toggle_reply");
  }

  get createDisabled() {
    if (
      !this.isEveryoneGroup &&
      this.everyonePermissionType &&
      this.everyonePermissionType === PermissionType.FULL
    ) {
      return true;
    }
    return false;
  }

  get createTooltip() {
    return this.createDisabled
      ? I18n.t("category.permissions.inherited")
      : I18n.t("category.permissions.toggle_full");
  }

  get groupLink() {
    return getURL(`/g/${this.args.groupName}`);
  }

  @action
  removeRow(event) {
    event?.preventDefault();
    this.args.category.removePermission(this.args.groupName);
  }

  @action
  setPermissionReply() {
    if (this.args.type <= PermissionType.CREATE_POST) {
      this.#updatePermission(PermissionType.READONLY);
    } else {
      this.#updatePermission(PermissionType.CREATE_POST);
    }
  }

  @action
  setPermissionFull() {
    if (
      !this.isEveryoneGroup &&
      this.everyonePermissionType === PermissionType.FULL
    ) {
      return;
    }

    if (this.args.type === PermissionType.FULL) {
      this.#updatePermission(PermissionType.CREATE_POST);
    } else {
      this.#updatePermission(PermissionType.FULL);
    }
  }

  #updatePermission(type) {
    this.args.category.updatePermission(this.args.groupName, type);
  }

  <template>
    <div class="permission-row row-body" data-group-name={{@groupName}}>
      <span class="group-name">
        {{#if this.isEveryoneGroup}}
          <span class="group-name-label">{{@groupName}}</span>
        {{else}}
          <a href="{{this.groupLink}}">{{@groupName}}</a>
        {{/if}}
      </span>
      <span class="options actionable">
        <DButton @icon="check-square" @disabled={{true}} class="btn-flat see" />

        <DButton
          @icon={{this.canReplyIcon}}
          @action={{this.setPermissionReply}}
          @translatedTitle={{this.replyTooltip}}
          @disabled={{this.replyDisabled}}
          class={{concatClass "btn btn-flat reply-toggle" this.replyGranted}}
        />

        <DButton
          @icon={{this.canCreateIcon}}
          @action={{this.setPermissionFull}}
          @translatedTitle={{this.createTooltip}}
          @disabled={{this.createDisabled}}
          class={{concatClass "btn-flat create-toggle" this.createGranted}}
        />

        <a class="remove-permission" href {{on "click" this.removeRow}}>
          {{dIcon "far-trash-alt"}}
        </a>
      </span>
    </div>
  </template>
}

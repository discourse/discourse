import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import getURL from "discourse/lib/get-url";
import PermissionType from "discourse/models/permission-type";
import { i18n } from "discourse-i18n";

const EVERYONE = "everyone";

export default class CategoryPermissionRow extends Component {
  @service currentUser;

  get everyonePermissionType() {
    return this.args.everyonePermission?.permission_type;
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
    return this.canCreate ? "square-check" : "far-square";
  }

  get canReplyIcon() {
    return this.canReply ? "square-check" : "far-square";
  }

  get replyGrantedClass() {
    return this.args.type <= PermissionType.CREATE_POST ? "reply-granted" : "";
  }

  get createGrantedClass() {
    return this.args.type === PermissionType.FULL ? "create-granted" : "";
  }

  get isEveryoneGroup() {
    return this.args.groupName === EVERYONE;
  }

  get replyDisabled() {
    // If everyone has create permission then it doesn't make sense to
    // be able to remove reply for other groups
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
      ? i18n("category.permissions.inherited")
      : i18n("category.permissions.toggle_reply");
  }

  get createDisabled() {
    // If everyone has full permission then it doesn't make sense to
    // be able to remove create for other groups
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
      ? i18n("category.permissions.inherited")
      : i18n("category.permissions.toggle_full");
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

    if (this.isEveryoneGroup) {
      this.args.onChangeEveryonePermission(type);
    }
  }

  <template>
    <div class="permission-row row-body" data-group-name={{@groupName}}>
      <span class="group-name">
        {{#if this.isEveryoneGroup}}
          <span class="group-name-label">{{@groupName}}</span>
        {{else}}
          <a class="group-name-link" href={{this.groupLink}}>{{@groupName}}</a>
        {{/if}}
      </span>
      <span class="options actionable">
        <DButton @icon="square-check" @disabled={{true}} class="btn-flat see" />

        <DButton
          @icon={{this.canReplyIcon}}
          @action={{this.setPermissionReply}}
          @translatedTitle={{this.replyTooltip}}
          @disabled={{this.replyDisabled}}
          class={{concatClass
            "btn btn-flat reply-toggle"
            this.replyGrantedClass
          }}
        />

        <DButton
          @icon={{this.canCreateIcon}}
          @action={{this.setPermissionFull}}
          @translatedTitle={{this.createTooltip}}
          @disabled={{this.createDisabled}}
          class={{concatClass "btn-flat create-toggle" this.createGrantedClass}}
        />

        <DButton
          class="remove-permission btn-flat"
          @action={{this.removeRow}}
          @icon="trash-can"
        />
      </span>
    </div>
  </template>
}

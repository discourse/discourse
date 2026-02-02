import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { AUTO_GROUPS } from "discourse/lib/constants";
import getURL from "discourse/lib/get-url";
import PermissionType from "discourse/models/permission-type";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryPermissionRow extends Component {
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
    return this.args.groupId === AUTO_GROUPS.everyone.id;
  }

  get replyDisabled() {
    return (
      !this.isEveryoneGroup &&
      this.everyonePermissionType &&
      this.everyonePermissionType <= PermissionType.CREATE_POST
    );
  }

  get replyTooltip() {
    return this.replyDisabled
      ? i18n("category.permissions.inherited")
      : i18n("category.permissions.toggle_reply");
  }

  get createDisabled() {
    return (
      !this.isEveryoneGroup &&
      this.everyonePermissionType &&
      this.everyonePermissionType === PermissionType.FULL
    );
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
    this.args.onRemovePermission(this.args.groupName);
  }

  @action
  setPermissionReply() {
    let newType;
    if (this.args.type <= PermissionType.CREATE_POST) {
      newType = PermissionType.READONLY;
    } else {
      newType = PermissionType.CREATE_POST;
    }

    this.args.onUpdatePermission(this.args.groupName, newType);

    if (this.isEveryoneGroup) {
      this.args.onChangeEveryonePermission(newType);
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

    let newType;
    if (this.args.type === PermissionType.FULL) {
      newType = PermissionType.CREATE_POST;
    } else {
      newType = PermissionType.FULL;
    }

    this.args.onUpdatePermission(this.args.groupName, newType);

    if (this.isEveryoneGroup) {
      this.args.onChangeEveryonePermission(newType);
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

        <PluginOutlet
          @name="category-security-permissions-row-actions"
          @outletArgs={{lazyHash
            groupName=@groupName
            groupId=@groupId
            canReplyIcon=this.canReplyIcon
            canCreateIcon=this.canCreateIcon
            replyTooltip=this.replyTooltip
            createTooltip=this.createTooltip
            replyDisabled=this.replyDisabled
            createDisabled=this.createDisabled
            replyGrantedClass=this.replyGrantedClass
            createGrantedClass=this.createGrantedClass
            setPermissionReply=this.setPermissionReply
            setPermissionFull=this.setPermissionFull
            removeRow=this.removeRow
          }}
          @defaultGlimmer={{true}}
        >
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
            class={{concatClass
              "btn-flat create-toggle"
              this.createGrantedClass
            }}
          />

          <DButton
            class="remove-permission btn-flat"
            @action={{this.removeRow}}
            @icon="trash-can"
          />
        </PluginOutlet>
      </span>
    </div>
  </template>
}

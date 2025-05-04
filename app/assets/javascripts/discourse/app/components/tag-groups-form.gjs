import { cached, tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import BufferedProxy from "ember-buffered-proxy/proxy";
import DButton from "discourse/components/d-button";
import RadioButton from "discourse/components/radio-button";
import TextField from "discourse/components/text-field";
import discourseComputed from "discourse/lib/decorators";
import PermissionType from "discourse/models/permission-type";
import { i18n } from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import TagChooser from "select-kit/components/tag-chooser";

@tagName("")
export default class TagGroupsForm extends Component {
  @service router;
  @service dialog;
  @service site;

  @tracked model;

  // All but the "everyone" group
  allGroups = this.site.groups.filter(({ id }) => id !== 0);

  @cached
  @dependentKeyCompat
  get buffered() {
    return BufferedProxy.create({
      content: this.model,
    });
  }

  @discourseComputed("buffered.permissions")
  selectedGroupIds(permissions) {
    if (!permissions) {
      return [];
    }

    let groupIds = [];

    for (const [groupId, permission] of Object.entries(permissions)) {
      // JS object keys are always strings, so we need to convert them to integers
      const id = parseInt(groupId, 10);

      if (id !== 0 && permission === PermissionType.FULL) {
        groupIds.push(id);
      }
    }

    return groupIds;
  }

  @action
  setPermissionsGroups(groupIds) {
    let permissions = {};
    groupIds.forEach((id) => (permissions[id] = PermissionType.FULL));
    this.buffered.set("permissions", permissions);
  }

  @action
  save() {
    const attrs = this.buffered.getProperties(
      "name",
      "tag_names",
      "parent_tag_name",
      "one_per_topic",
      "permissions"
    );

    if (isEmpty(attrs.name)) {
      this.dialog.alert("tagging.groups.cannot_save.empty_name");
      return false;
    }

    if (isEmpty(attrs.tag_names)) {
      this.dialog.alert("tagging.groups.cannot_save.no_tags");
      return false;
    }

    attrs.permissions ??= {};

    const permissionName = this.buffered.get("permissionName");

    if (permissionName === "public") {
      attrs.permissions = { 0: PermissionType.FULL };
    } else if (permissionName === "visible") {
      attrs.permissions[0] = PermissionType.READONLY;
    } else if (permissionName === "private") {
      delete attrs.permissions[0];
    } else {
      this.dialog.alert("tagging.groups.cannot_save.no_groups");
      return false;
    }

    this.model.save(attrs).then(() => this.onSave?.());
  }

  @action
  destroyTagGroup() {
    return this.dialog.yesNoConfirm({
      message: i18n("tagging.groups.confirm_delete"),
      didConfirm: () =>
        this.model.destroyRecord().then(() => this.onDestroy?.()),
    });
  }

  <template>
    <section class="group-name">
      <label>{{i18n "tagging.groups.name_placeholder"}}</label>
      <div>
        <TextField @value={{this.buffered.name}} /></div>
    </section>

    <section class="group-tags-list">
      <label>{{i18n "tagging.groups.tags_label"}}</label><br />
      <TagChooser
        @tags={{this.buffered.tag_names}}
        @everyTag={{true}}
        @unlimitedTagCount={{true}}
        @excludeSynonyms={{true}}
        @options={{hash
          allowAny=true
          filterPlaceholder="tagging.groups.tags_placeholder"
        }}
      />
    </section>

    <section class="parent-tag-section">
      <label>{{i18n "tagging.groups.parent_tag_label"}}</label>
      <div>
        <TagChooser
          @tags={{this.buffered.parent_tag_name}}
          @everyTag={{true}}
          @excludeSynonyms={{true}}
          @options={{hash
            allowAny=true
            filterPlaceholder="tagging.groups.parent_tag_placeholder"
            maximum=1
          }}
        />
      </div>
      <div class="description">{{i18n
          "tagging.groups.parent_tag_description"
        }}</div>
    </section>

    <section class="group-one-per-topic">
      <label>
        <Input
          @type="checkbox"
          @checked={{this.buffered.one_per_topic}}
          name="onepertopic"
        />
        {{i18n "tagging.groups.one_per_topic_label"}}
      </label>
    </section>

    <section class="group-visibility">
      <div class="group-visibility-option">
        <RadioButton
          @name="tag-permissions-choice"
          @value="public"
          @id="public-permission"
          @selection={{this.buffered.permissionName}}
          class="tag-permissions-choice"
        />

        <label class="radio" for="public-permission">
          {{i18n "tagging.groups.everyone_can_use"}}
        </label>
      </div>
      <div class="group-visibility-option">
        <RadioButton
          @name="tag-permissions-choice"
          @value="visible"
          @id="visible-permission"
          @selection={{this.buffered.permissionName}}
          class="tag-permissions-choice"
        />

        <label class="radio" for="visible-permission">
          {{i18n "tagging.groups.usable_only_by_groups"}}
        </label>

        <div class="group-access-control">
          <GroupChooser
            @content={{this.allGroups}}
            @value={{this.selectedGroupIds}}
            @labelProperty="name"
            @onChange={{this.setPermissionsGroups}}
            @options={{hash
              filterPlaceholder="tagging.groups.select_groups_placeholder"
            }}
          />
        </div>
      </div>
      <div class="group-visibility-option">
        <RadioButton
          @name="tag-permissions-choice"
          @value="private"
          @id="private-permission"
          @selection={{this.buffered.permissionName}}
          class="tag-permissions-choice"
        />

        <label class="radio" for="private-permission">
          {{i18n "tagging.groups.visible_only_to_groups"}}
        </label>

        <div class="group-access-control">
          <GroupChooser
            @content={{this.allGroups}}
            @value={{this.selectedGroupIds}}
            @labelProperty="name"
            @onChange={{this.setPermissionsGroups}}
            @options={{hash
              filterPlaceholder="tagging.groups.select_groups_placeholder"
            }}
          />
        </div>
      </div>
    </section>

    <div class="tag-group-controls">
      <DButton
        @action={{this.save}}
        @disabled={{this.buffered.isSaving}}
        @label="tagging.groups.save"
        class="btn-primary"
      />

      <DButton
        @action={{this.destroyTagGroup}}
        @disabled={{this.buffered.isNew}}
        @icon="trash-can"
        @label="tagging.groups.delete"
        class="btn-danger"
      />
    </div>
  </template>
}

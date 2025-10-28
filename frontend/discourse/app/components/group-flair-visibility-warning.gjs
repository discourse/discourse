import Component from "@glimmer/component";
import { get } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { i18n } from "discourse-i18n";

export default class GroupFlairVisibilityWarning extends Component {
  @dependentKeyCompat
  get hasFlair() {
    const flairIcon = get(this.args.model, "flair_icon");
    const flairUrl = get(this.args.model, "flair_url");
    return !!(flairIcon || flairUrl);
  }

  @dependentKeyCompat
  get privateGroupNameNotice() {
    const visibilityLevel = get(this.args.model, "visibility_level");
    const isPrimaryGroup = get(this.args.model, "primary_group");
    const groupName = get(this.args.model, "name");

    if (visibilityLevel === 0) {
      return;
    }

    if (isPrimaryGroup) {
      return i18n("admin.groups.manage.alert.primary_group", {
        group_name: groupName,
      });
    } else if (this.hasFlair) {
      return i18n("admin.groups.manage.alert.flair_group", {
        group_name: groupName,
      });
    }
  }

  <template>
    {{#if this.privateGroupNameNotice}}
      <div class="row">
        <div class="alert alert-warning alert-private-group-name">
          {{this.privateGroupNameNotice}}
        </div>
      </div>
    {{/if}}
  </template>
}

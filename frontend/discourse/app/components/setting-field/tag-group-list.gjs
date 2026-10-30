import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { splitString } from "discourse/lib/utilities";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import { i18n } from "discourse-i18n";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldTagGroupList extends Component {
  @service siteSettings;

  get selectedTagGroups() {
    return splitString(this.args.field.value, TOKEN_SEPARATOR);
  }

  @action
  onChange(tagGroups) {
    this.args.field.set(tagGroups.join(TOKEN_SEPARATOR));
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectTagGroup
          @disabled={{@field.disabled}}
          @multiple={{true}}
          @onChange={{this.onChange}}
          @placeholder={{i18n "category.required_tag_group.placeholder"}}
          @value={{this.selectedTagGroups}}
        />
      {{else}}
        <TagGroupChooser
          @onChange={{this.onChange}}
          @options={{hash
            filterPlaceholder="category.required_tag_group.placeholder"
            disabled=@field.disabled
          }}
          @tagGroups={{this.selectedTagGroups}}
        />
      {{/if}}
    </@field.Control>
  </template>
}

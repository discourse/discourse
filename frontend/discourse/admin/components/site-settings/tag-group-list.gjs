import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import { i18n } from "discourse-i18n";

export default class TagGroupList extends Component {
  @service siteSettings;

  get selectedTagGroups() {
    return this.args.value.split("|").filter(Boolean);
  }

  @action
  onTagGroupChange(tagGroups) {
    this.args.changeValueCallback(tagGroups.join("|"));
  }

  <template>
    <div ...attributes>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectTagGroup
          @disabled={{@disabled}}
          @multiple={{true}}
          @onChange={{this.onTagGroupChange}}
          @texts={{hash
            placeholder=(i18n "category.required_tag_group.placeholder")
          }}
          @value={{this.selectedTagGroups}}
        />
      {{else}}
        <TagGroupChooser
          @onChange={{this.onTagGroupChange}}
          @options={{hash
            filterPlaceholder="category.required_tag_group.placeholder"
            disabled=@disabled
          }}
          @tagGroups={{this.selectedTagGroups}}
        />
      {{/if}}
    </div>
  </template>
}

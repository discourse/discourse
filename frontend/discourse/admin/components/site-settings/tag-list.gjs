import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DTagChooser from "discourse/ui-kit/select/recipes/tags/d-tag-chooser";

export default class TagList extends Component {
  @service siteSettings;

  get selectedTags() {
    return this.args.value.split("|").filter(Boolean);
  }

  @action
  changeSelectedTags(tags) {
    this.args.changeValueCallback(tags.map((t) => t.name).join("|"));
  }

  <template>
    <div ...attributes>
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DTagChooser
          @allowCreate={{false}}
          @disabled={{@disabled}}
          @everyTag={{true}}
          @onChange={{this.changeSelectedTags}}
          @tags={{this.selectedTags}}
          @unlimitedTagCount={{true}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <TagChooser
          @everyTag={{true}}
          @onChange={{this.changeSelectedTags}}
          @options={{hash allowAny=false disabled=@disabled}}
          @tags={{this.selectedTags}}
          @unlimitedTagCount={{true}}
        />
      {{/if}}
    </div>
  </template>
}

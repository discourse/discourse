import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import DMiniTagChooser from "discourse/ui-kit/select/recipes/tags/d-mini-tag-chooser";

export default class MiniTagChooserHeaderFilterExample extends Component {
  @service siteSettings;

  @tracked tags = ["apple", "orange", "potato"];

  @action
  onChange(tags) {
    this.tags = tags;
  }

  <template>
    {{#if this.siteSettings.enable_new_select_controls}}
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      <DMiniTagChooser @onChange={{this.onChange}} @value={{this.tags}} />
    {{else}}
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      <MiniTagChooser
        @onChange={{this.onChange}}
        @options={{hash
          filterable=true
          filterPlaceholder="tagging.choose_for_topic"
          useHeaderFilter=true
        }}
        @value={{this.tags}}
      />
    {{/if}}
  </template>
}

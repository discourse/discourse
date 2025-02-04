import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";

export default class GroupInfo extends Component {
  <template>
    <PluginOutlet
      @name="group-info-details"
      @outletArgs={{hash group=@group}}
      @defaultGlimmer={{true}}
    >
      <span class="group-info-details">
        <span class="group-info-name">
          {{this.name}}
        </span>
        {{#if this.mentionName}}
          <span class="group-info-mention-name">
            {{this.mentionName}}
          </span>
        {{/if}}
      </span>
    </PluginOutlet>
  </template>

  get names() {
    const { full_name, display_name, name } = this.args.group;
    return [...new Set([full_name, display_name, name].filter(Boolean))];
  }

  get name() {
    return this.names[0];
  }

  get mentionName() {
    return this.names[1] ? `@${this.names[1]}` : null;
  }
}

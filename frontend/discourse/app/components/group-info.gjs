import Component from "@glimmer/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";

export default class GroupInfo extends Component {
  <template>
    <PluginOutlet
      @name="group-info-details"
      @outletArgs={{lazyHash group=@group}}
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
    return uniqueItemsFromArray(
      [full_name, display_name, name].filter(Boolean)
    );
  }

  get name() {
    return this.names[0];
  }

  get mentionName() {
    return this.names[1] ? `@${this.names[1]}` : null;
  }
}

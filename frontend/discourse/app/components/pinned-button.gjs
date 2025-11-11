import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import PinnedOptions from "discourse/components/pinned-options";
import { i18n } from "discourse-i18n";

export default class PinnedButton extends Component {
  get reasonText() {
    const pinnedGlobally = this.args.topic?.pinned_globally;
    const pinned = this.args.pinned;
    const globally = pinnedGlobally ? "_globally" : "";
    const pinnedKey = pinned ? `pinned${globally}` : "unpinned";
    const key = `topic_statuses.${pinnedKey}.help`;
    return i18n(key);
  }

  get isHidden() {
    const pinned = this.args.pinned;
    const deleted = this.args.topic?.deleted;
    const unpinned = this.args.topic?.unpinned;
    return deleted || (!pinned && !unpinned);
  }

  <template>
    {{#unless this.isHidden}}
      <div class="pinned-button" ...attributes>
        {{#if @appendReason}}
          <p class="reason">
            <PinnedOptions @value={{@pinned}} @topic={{@topic}} />
            <span class="text">{{htmlSafe this.reasonText}}</span>
          </p>
        {{else}}
          <PinnedOptions @value={{@pinned}} @topic={{@topic}} />
        {{/if}}
      </div>
    {{/unless}}
  </template>
}

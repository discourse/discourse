import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";

function offsetStyle(reaction) {
  return trustHTML(`--live-reaction-offset: ${reaction.offset}%`);
}

export default class LiveReactionOverlay extends Component {
  @service liveWebrtc;

  get reactions() {
    return this.liveWebrtc.reactionsFor(this.args.room.id);
  }

  <template>
    {{! Purely decorative: screen readers would otherwise announce every
    reaction, which drowns out the call in a busy room. }}
    <div aria-hidden="true" class="live-reactions">
      {{#each this.reactions key="id" as |reaction|}}
        <span
          class="live-reactions__item"
          data-emoji={{reaction.emoji}}
          style={{offsetStyle reaction}}
        >
          <span class="live-reactions__emoji">{{dEmoji reaction.emoji}}</span>
          <span class="live-reactions__username">{{reaction.username}}</span>
        </span>
      {{/each}}
    </div>
  </template>
}

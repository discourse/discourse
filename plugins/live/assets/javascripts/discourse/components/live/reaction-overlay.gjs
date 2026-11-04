import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DAnimatedEmoji from "discourse/ui-kit/d-animated-emoji";

function offsetStyle(reaction) {
  return trustHTML(`--live-reaction-offset: ${reaction.offset}%`);
}

export default class LiveReactionOverlay extends Component {
  @service emojiStore;
  @service liveReactions;

  constructor() {
    super(...arguments);
    // Reactions learn which emojis are animated from the emoji list; fetching
    // it on joining the call means even the first one can float animated.
    this.emojiStore.loadList().catch(() => {});
  }

  get reactions() {
    return this.liveReactions.reactionsFor(this.args.room.id);
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
          <DAnimatedEmoji
            class="live-reactions__emoji"
            @code={{reaction.emoji}}
          />
          <span class="live-reactions__username">{{reaction.username}}</span>
        </span>
      {{/each}}
    </div>
  </template>
}

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dSwipe from "discourse/ui-kit/modifiers/d-swipe";
import { i18n } from "discourse-i18n";

export default class SwipeExample extends Component {
  @tracked direction;

  @action
  onDidEndSwipe(state) {
    this.direction = state.direction;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__swipe"
        {{dSwipe onDidEndSwipe=this.onDidEndSwipe}}
      >{{i18n "styleguide.sections.drag_and_drop.swipe_here"}}</div>

      <p class="styleguide-example__result">
        {{#if this.direction}}
          {{i18n
            "styleguide.sections.drag_and_drop.swiped"
            direction=this.direction
          }}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}

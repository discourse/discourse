import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { next } from "@ember/runloop";
import { waitForAnimationEnd } from "discourse/lib/animation-utils";

export default class AdminWatchedWordsActionNav extends Component {
  get items() {
    return this.args.items ?? this.args.data?.items ?? [];
  }

  @action
  onLinkClick() {
    next(() => this.args.close?.());
  }

  @action
  async scrollToActive(element) {
    const modalContainer = element.closest(".d-modal__container");
    if (modalContainer) {
      await waitForAnimationEnd(modalContainer);
    }
    element.querySelector("a.active")?.scrollIntoView({ block: "center" });
  }

  <template>
    <ul class="nav nav-stacked" {{didInsert this.scrollToActive}}>
      {{#each this.items as |watchedWordAction|}}
        <li class={{watchedWordAction.nameKey}}>
          <LinkTo
            @route="adminWatchedWords.action"
            @model={{watchedWordAction.nameKey}}
            {{on "click" this.onLinkClick}}
          >
            {{watchedWordAction.name}}
            {{#if watchedWordAction.words}}
              <span class="count">({{watchedWordAction.words.length}})</span>
            {{/if}}
          </LinkTo>
        </li>
      {{/each}}
    </ul>
  </template>
}

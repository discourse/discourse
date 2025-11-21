import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import scrollIntoView from "discourse/modifiers/scroll-into-view";
import { eq } from "discourse/truth-helpers";

export default class EmojiAutocompleteResults extends Component {
  static TRIGGER_KEY = ":";

  @tracked isInitialRender = true;

  @action
  handleResultClick(result, index, event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.onSelect(result, index, event);
  }

  @action
  handleInsert() {
    this.args.onRender?.(this.args.results);
  }

  @action
  handleUpdate() {
    this.isInitialRender = false;
    this.args.onRender?.(this.args.results);
  }

  @action
  shouldScroll(index) {
    return index === this.args.selectedIndex && !this.isInitialRender;
  }

  <template>
    <div
      class="autocomplete ac-emoji"
      {{didInsert this.handleInsert}}
      {{didUpdate this.handleUpdate @selectedIndex}}
    >
      <ul>
        {{#each @results as |result index|}}
          <li {{scrollIntoView (this.shouldScroll index)}}>
            <a
              href
              class={{if (eq index @selectedIndex) "selected"}}
              {{on "click" (fn this.handleResultClick result index)}}
            >
              <span class="text-content">
                {{#if result.src}}
                  <img src={{result.src}} class="emoji" />
                  <span class="emoji-shortname">{{result.code}}</span>
                {{else}}
                  {{result.label}}
                {{/if}}
              </span>
            </a>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}

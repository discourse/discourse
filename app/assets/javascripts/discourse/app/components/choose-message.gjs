import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { TrackedAsyncData } from "ember-async-data";
import { and } from "truth-helpers";
import { debounce } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import { searchForTerm } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

export default class ChooseMessage extends Component {
  @tracked searchedValue;
  @tracked hasSearched = false;

  @debounce(INPUT_DELAY)
  setSearchTerm(event) {
    this.searchedValue = event.target.value;

    this.hasSearched = true;
    this.args.setSelectedTopicId(null);
  }

  @cached
  get messages() {
    return new TrackedAsyncData(this.search(this.searchedValue));
  }

  @action
  async search(title) {
    if (isEmpty(title)) {
      return;
    }

    const results = await searchForTerm(title, {
      typeFilter: "private_messages",
      searchForId: true,
      restrictToArchetype: "private_message",
    });

    return results?.posts
      ?.mapBy("topic")
      .filter((topic) => topic.id !== this.args.currentTopicId);
  }

  <template>
    <div>
      <label for="choose-message-title">
        {{i18n "choose_message.title.search"}}
      </label>

      <input
        {{on "input" this.setSearchTerm}}
        type="text"
        placeholder={{i18n "choose_message.title.placeholder"}}
        id="choose-message-title"
      />

      {{#if this.messages.isPending}}
        <p>{{i18n "loading"}}</p>
      {{else if (and this.hasSearched this.messages.isResolved)}}
        {{#each this.messages.value as |message|}}
          <div class="controls existing-message">
            <label class="radio">
              <input
                {{on "click" (fn @setSelectedTopicId message)}}
                type="radio"
                name="choose_message_id"
              />
              <span class="message-title">
                {{message.title}}
              </span>
            </label>
          </div>
        {{else}}
          <p>{{i18n "choose_message.none_found"}}</p>
        {{/each}}
      {{/if}}
    </div>
  </template>
}

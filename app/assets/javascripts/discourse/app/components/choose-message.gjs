import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { debounce } from "discourse/lib/decorators";
import { searchForTerm } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

export default class ChooseMessage extends Component {
  @tracked hasSearched = false;
  @tracked loading = false;
  @tracked messages;

  @debounce(300)
  async debouncedSearch(title) {
    if (isEmpty(title)) {
      this.messages = null;
      this.loading = false;
      return;
    }

    const results = await searchForTerm(title, {
      typeFilter: "private_messages",
      searchForId: true,
      restrictToArchetype: "private_message",
    });

    this.messages = results?.posts
      ?.mapBy("topic")
      .filter((topic) => topic.id !== this.args.currentTopicId);

    this.loading = false;
  }

  @action
  search(event) {
    this.hasSearched = true;
    this.loading = true;
    this.args.setSelectedTopicId(null);
    this.debouncedSearch(event.target.value);
  }

  <template>
    <div>
      <label for="choose-message-title">
        {{i18n "choose_message.title.search"}}
      </label>

      <input
        {{on "input" this.search}}
        type="text"
        placeholder={{i18n "choose_message.title.placeholder"}}
        id="choose-message-title"
      />

      {{#if this.loading}}
        <p>{{i18n "loading"}}</p>
      {{else if this.hasSearched}}
        {{#each this.messages as |message|}}
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

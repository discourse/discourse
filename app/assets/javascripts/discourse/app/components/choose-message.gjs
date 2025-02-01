import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import AsyncContent from "discourse/components/async-content";
import { INPUT_DELAY } from "discourse/lib/environment";
import { searchForTerm } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

export default class ChooseMessage extends Component {
  @tracked searchedTitle;

  @action
  async search(title) {
    this.args.setSelectedTopicId(null);

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

  @action
  setSearchTerm(evt) {
    this.searchedTitle = evt.target.value;
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

      <AsyncContent
        @asyncData={{this.search}}
        @context={{this.searchedTitle}}
        @debounce={{INPUT_DELAY}}
        @loadOnInit={{false}}
      >
        <:loading>
          <p>{{i18n "loading"}}</p>
        </:loading>
        <:content as |messages|>
          {{#each messages as |message|}}
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
        </:content>
      </AsyncContent>
    </div>
  </template>
}

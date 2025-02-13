import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import AsyncContent from "discourse/components/async-content";
import { searchForTerm } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

export default class ChooseMessage extends Component {
  @tracked messageTitle = null;

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
    this.messageTitle = evt.target.value;
  }

  <template>
    <div class="choose-message">
      <label for="choose-message-title">
        {{i18n "choose_message.title.search"}}
      </label>

      <input
        {{on "input" this.setSearchTerm}}
        type="text"
        placeholder={{i18n "choose_message.title.placeholder"}}
        id="choose-message-title"
      />

      <div class="choose-message__search-results">
        <AsyncContent
          @asyncData={{this.search}}
          @context={{this.messageTitle}}
          @debounce={{true}}
        >
          <:loading>
            {{i18n "loading"}}
          </:loading>

          <:empty>
            {{#if this.messageTitle}}
              {{i18n "choose_message.none_found"}}
            {{else}}
              {{! ensure the paragraph has the same height as the loading message to prevent layout shift }}
              &nbsp;
            {{/if}}
          </:empty>

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
            {{/each}}
          </:content>
        </AsyncContent>
      </div>
    </div>
  </template>
}

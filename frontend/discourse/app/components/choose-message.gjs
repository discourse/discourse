import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { searchForTerm } from "discourse/lib/search";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSelectTopicList from "discourse/ui-kit/select/recipes/topics/d-select-topic-list";
import { i18n } from "discourse-i18n";

export default class ChooseMessage extends Component {
  @service siteSettings;

  /** @type {string | null} */
  @tracked messageTitle = null;

  /** The message being worked on, which is never offered. */
  get excludedTopicIds() {
    return this.args.currentTopicId ? [this.args.currentTopicId] : [];
  }

  @action
  async search(title) {
    next(() => this.args.setSelectedTopicId(null)); // clear existing selection

    if (isEmpty(title)) {
      return;
    }

    const results = await searchForTerm(title, {
      typeFilter: "private_messages",
      searchForId: true,
      restrictToArchetype: "private_message",
    });

    const messages = results?.posts
      ?.map((item) => item.topic)
      .filter((topic) => topic.id !== this.args.currentTopicId);

    if (messages.length === 1) {
      next(() => this.args.setSelectedTopicId(messages[0]));
    }

    return messages;
  }

  @action
  setSearchTerm(evt) {
    this.messageTitle = evt.target.value;
  }

  @action
  onChangeMessage(_topicId, message) {
    this.args.setSelectedTopicId(message);
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy search after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <div class="choose-message">
        <label for="choose-message-title">
          {{i18n "choose_message.title.search"}}
        </label>
        <DSelectTopicList
          @archetype="private_message"
          @exclude={{this.excludedTopicIds}}
          @id="choose-message-title"
          @multiple={{false}}
          @onChange={{this.onChangeMessage}}
          @texts={{hash ariaLabel=(i18n "choose_message.title.search")}}
          @value={{@selectedTopicId}}
        />
      </div>
    {{else}}
      <div class="choose-message">
        <label for="choose-message-title">
          {{i18n "choose_message.title.search"}}
        </label>

        <input
          id="choose-message-title"
          placeholder={{i18n "choose_message.title.placeholder"}}
          type="text"
          {{on "input" this.setSearchTerm}}
        />

        <div class="choose-message__search-results">
          <DAsyncContent
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
                      checked={{eq message.id @selectedTopicId}}
                      name="choose_message_id"
                      type="radio"
                      {{on "click" (fn @setSelectedTopicId message)}}
                    />
                    <span class="message-title">
                      {{message.title}}
                    </span>
                  </label>
                </div>
              {{/each}}
            </:content>
          </DAsyncContent>
        </div>
      </div>
    {{/if}}
  </template>
}

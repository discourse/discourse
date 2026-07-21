import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DDockPanel from "discourse/ui-kit/d-dock-panel";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import { messageBusState, subscriptions } from "./instrumentation";

const REFRESH_INTERVAL = 1000;

/**
 * Shows what MessageBus is currently doing.
 *
 * The subscription list is read from MessageBus' own live array, which is a
 * plain array rather than tracked state, so it cannot announce its own changes.
 * The panel therefore re-reads it on a timer while it is open. Received
 * messages do not need that: they are recorded into tracked state as they
 * arrive.
 */
export default class MessageBusPanel extends Component {
  #timer = null;
  @tracked _refreshedAt = 0;

  constructor() {
    super(...arguments);

    // Deliberately not an Ember runloop timer. A repeating runloop timer never
    // lets the application settle, which would hang every test that waits for
    // it. This one is outside the runloop and cancelled on teardown.
    this.#timer = setInterval(() => {
      this._refreshedAt = Date.now();
    }, REFRESH_INTERVAL);

    registerDestructor(this, () => clearInterval(this.#timer));
  }

  /**
   * The current subscriptions, re-read whenever the refresh timer fires.
   *
   * @returns {Array<Object>} One entry per subscription.
   */
  get subscriptions() {
    // Consumed so that the timer invalidates this getter.
    this._refreshedAt;

    return subscriptions();
  }

  get state() {
    return messageBusState();
  }

  /**
   * Subscriptions whose channel is subscribed more than once.
   *
   * Legal, but also what an unbalanced subscribe looks like, so it is worth
   * counting where a developer can see it.
   *
   * @returns {number} How many subscriptions sit on a duplicated channel.
   */
  get duplicateCount() {
    return this.subscriptions.filter((entry) => entry.duplicated).length;
  }

  @action
  close() {
    this.args.onClose();
  }

  <template>
    <DDockPanel
      @isOpen={{@isOpen}}
      @storageKey="dev-tools-message-bus"
      class="dev-tools-message-bus"
    >
      <:header>
        <span>{{i18n "dev_tools.message_bus.title"}}</span>
        <button
          type="button"
          class="dev-tools-message-bus__close"
          title={{i18n "dev_tools.message_bus.close"}}
          {{on "click" this.close}}
        >
          {{i18n "dev_tools.message_bus.close"}}
        </button>
      </:header>

      <:body>
        <p class="dev-tools-message-bus__summary">
          {{i18n
            "dev_tools.message_bus.summary"
            channels=this.subscriptions.length
            duplicates=this.duplicateCount
            polls=this.state.polls
          }}
        </p>

        <h3>{{i18n "dev_tools.message_bus.subscriptions"}}</h3>
        <table class="dev-tools-message-bus__subscriptions">
          <thead>
            <tr>
              <th>{{i18n "dev_tools.message_bus.channel"}}</th>
              <th>{{i18n "dev_tools.message_bus.position"}}</th>
              <th>{{i18n "dev_tools.message_bus.calls"}}</th>
              <th>{{i18n "dev_tools.message_bus.slowest"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.subscriptions key="id" as |entry|}}
              <tr
                class={{dConcatClass
                  (if entry.duplicated "--duplicated")
                  (if entry.errors "--failing")
                }}
                title={{entry.source}}
              >
                <td>{{entry.channel}}</td>
                <td>{{entry.lastId}}</td>
                <td>{{entry.calls}}</td>
                <td>{{entry.slowestMs}}</td>
              </tr>
              {{#if entry.lastError}}
                <tr class="dev-tools-message-bus__error">
                  <td colspan="4">{{entry.lastError}}</td>
                </tr>
              {{/if}}
            {{/each}}
          </tbody>
        </table>

        <h3>{{i18n "dev_tools.message_bus.messages"}}</h3>
        {{#if this.state.messages.length}}
          <ul class="dev-tools-message-bus__messages">
            {{#each this.state.messages key="messageId" as |message|}}
              <li>
                <span
                  class="dev-tools-message-bus__channel"
                >{{message.channel}}</span>
                <span
                  class="dev-tools-message-bus__id"
                >{{message.messageId}}</span>
              </li>
            {{/each}}
          </ul>
        {{else}}
          <p class="dev-tools-message-bus__empty">
            {{i18n "dev_tools.message_bus.no_messages"}}
          </p>
        {{/if}}
      </:body>
    </DDockPanel>
  </template>
}

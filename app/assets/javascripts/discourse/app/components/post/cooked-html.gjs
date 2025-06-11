import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import curryComponent from "ember-curry-component";
import DecoratedHtml from "discourse/components/decorated-html";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import decorateLinkCounts from "discourse/lib/post-cooked-html-decorators/link-counts";
import decorateMentions from "discourse/lib/post-cooked-html-decorators/mentions";
import decorateQuoteControls from "discourse/lib/post-cooked-html-decorators/quote-controls";
import decorateSearchHighlight from "discourse/lib/post-cooked-html-decorators/search-highlight";
import decorateSelectionBarrier from "discourse/lib/post-cooked-html-decorators/selection-barrier";
import { i18n } from "discourse-i18n";

const detachedDocument = document.implementation.createHTMLDocument("detached");

const POST_COOKED_DECORATORS = [
  decorateSelectionBarrier,
  decorateQuoteControls,
  decorateLinkCounts,
  decorateSearchHighlight,
  decorateMentions,
];

export default class PostCookedHtml extends Component {
  @service appEvents;
  @service currentUser;

  @tracked highlighted = false;
  #decoratorState = new WeakMap();
  #pendingDecoratorCleanup = [];

  willDestroy() {
    super.willDestroy(...arguments);
    this.#cleanupDecorations();
  }

  get isStreamElement() {
    return this.args.streamElement ?? true;
  }

  @bind
  decorateBeforeAdopt(element, helper) {
    this.#cleanupDecorations();

    [...POST_COOKED_DECORATORS, ...this.extraDecorators].forEach(
      (decorator) => {
        if (!this.#decoratorState.has(decorator)) {
          this.#decoratorState.set(decorator, {});
        }

        const owner = getOwner(this);
        const decorationCleanup = decorator(element, {
          data: {
            post: this.args.post,
            cooked: this.cooked,
            highlightTerm: this.highlightTerm,
            isIgnored: this.isIgnored,
            ignoredUsers: this.ignoredUsers,
          },
          createDetachedElement: this.#createDetachedElement,
          currentUser: this.currentUser,
          helper,
          renderNestedPostCookedHtml: (
            nestedElement,
            nestedPost,
            extraDecorators
          ) => {
            const nestedArguments = {
              post: nestedPost,
              streamElement: false,
              highlightTerm: this.highlightTerm,
              extraDecorators: [
                ...this.extraDecorators,
                ...makeArray(extraDecorators),
              ],
            };

            helper.renderGlimmer(
              nestedElement,
              curryComponent(PostCookedHtml, nestedArguments, owner)
            );
          },
          owner,
          state: this.#decoratorState.get(decorator),
        });

        if (typeof decorationCleanup === "function") {
          this.#pendingDecoratorCleanup.push(decorationCleanup);
        }
      }
    );

    this.appEvents.trigger(
      this.isStreamElement
        ? "decorate-post-cooked-element:before-adopt"
        : "decorate-non-stream-cooked-element",
      element,
      helper
    );
  }

  @bind
  decorateAfterAdopt(element, helper) {
    if (this.isStreamElement) {
      return;
    }

    this.appEvents.trigger(
      "decorate-post-cooked-element:after-adopt",
      element,
      helper
    );
  }

  get cooked() {
    if (this.isIgnored) {
      return i18n("post.ignored");
    }

    return this.args.post.cooked;
  }

  get highlightTerm() {
    return this.args.highlightTerm;
  }

  get extraDecorators() {
    return makeArray(this.args.extraDecorators);
  }

  get ignoredUsers() {
    return this.currentUser?.ignored_users;
  }

  get isIgnored() {
    return (
      (this.args.post.firstPost || this.args.embeddedPost) &&
      this.ignoredUsers?.includes?.(this.args.post.username)
    );
  }

  #cleanupDecorations() {
    this.#pendingDecoratorCleanup.forEach((teardown) => teardown());
    this.#pendingDecoratorCleanup = [];
  }

  #createDetachedElement(nodeName) {
    return detachedDocument.createElement(nodeName);
  }

  <template>
    <DecoratedHtml
      @className="cooked"
      @decorate={{this.decorateBeforeAdopt}}
      @decorateAfterAdopt={{this.decorateAfterAdopt}}
      @html={{htmlSafe this.cooked}}
      @model={{@post}}
    />
  </template>
}

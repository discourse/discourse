import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import curryComponent from "ember-curry-component";
import DecoratedHtml from "discourse/components/decorated-html";
import { bind } from "discourse/lib/decorators";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
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
  #pendingDecoratorCleanup = [];
  #decoratorState = this.args.decoratorState || new TrackedMap();

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
        try {
          let decoratorState;
          if (this.#decoratorState.has(decorator)) {
            decoratorState = this.#decoratorState.get(decorator);
          } else {
            decoratorState = new TrackedMap();
            this.#decoratorState.set(decorator, decoratorState);
          }

          const owner = getOwner(this);
          const renderNestedPostCookedHtml = (
            nestedElement,
            nestedPost,
            extraDecorators,
            extraArguments
          ) => {
            const nestedArguments = {
              ...extraArguments,
              post: nestedPost,
              decoratorState,
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
          };

          const decorationCleanup = decorator(element, {
            data: {
              post: this.args.post,
              cooked: this.cooked,
              highlightTerm: this.highlightTerm,
              isIgnored: this.isIgnored,
              ignoredUsers: this.ignoredUsers,
            },
            decoratorState,
            cooked: this.cooked,
            createDetachedElement: this.#createDetachedElement,
            currentUser: this.currentUser,
            extraDecorators: this.extraDecorators,
            helper,
            highlightTerm: this.highlightTerm,
            ignoredUsers: this.ignoredUsers,
            isIgnored: this.isIgnored,
            owner,
            post: this.args.post,
            renderGlimmer: helper.renderGlimmer,
            renderNestedPostCookedHtml,
          });

          if (typeof decorationCleanup === "function") {
            this.#pendingDecoratorCleanup.push(decorationCleanup);
          }
        } catch (e) {
          if (isRailsTesting() || isTesting()) {
            throw e;
          } else {
            // in case one of the decorators throws an error we want to surface it to the console but prevent
            // the application from crashing

            // eslint-disable-next-line no-console
            console.error(e);
          }
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
    if (!this.isStreamElement) {
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

import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import curryComponent from "ember-curry-component";
import DecoratedHtml, {
  applyHtmlDecorators,
  NON_STREAM_HTML_DECORATOR,
} from "discourse/components/decorated-html";
import lazyHash from "discourse/helpers/lazy-hash";
import { bind } from "discourse/lib/decorators";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { makeArray } from "discourse/lib/helpers";
import decorateLinkCounts from "discourse/lib/post-cooked-html-decorators/link-counts";
import decorateMentions from "discourse/lib/post-cooked-html-decorators/mentions";
import decorateQuoteControls from "discourse/lib/post-cooked-html-decorators/quote-controls";
import decorateSearchHighlight from "discourse/lib/post-cooked-html-decorators/search-highlight";
import decorateSelectionBarrier from "discourse/lib/post-cooked-html-decorators/selection-barrier";
import decorateStatefulHtmlElements from "discourse/lib/post-cooked-html-decorators/stateful-html-elements";
import { i18n } from "discourse-i18n";

const detachedDocument = document.implementation.createHTMLDocument("detached");

const POST_COOKED_DECORATORS = [
  decorateStatefulHtmlElements,
  decorateQuoteControls,
  decorateLinkCounts,
  decorateSearchHighlight,
  decorateMentions,
];

export const STREAM_HTML_DECORATOR = Symbol("stream-html-decorator");

export default class PostCookedHtml extends Component {
  @service currentUser;

  #pendingDecoratorCleanup = [];
  #decoratorState = this.args.decoratorState || new TrackedMap();

  willDestroy() {
    super.willDestroy(...arguments);
    this.#cleanupDecorations();
  }

  get isStreamElement() {
    return this.args.streamElement ?? false;
  }

  get shouldAddSelectionBarrier() {
    return this.args.selectionBarrier ?? true;
  }

  @bind
  decorate(element, helper, args) {
    this.#cleanupDecorations();

    const decorators = [...POST_COOKED_DECORATORS, ...this.extraDecorators];
    if (this.shouldAddSelectionBarrier) {
      decorators.push(decorateSelectionBarrier);
    }

    decorators.forEach((decorator) => {
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
            streamElement: this.isStreamElement,
            highlightTerm: args.highlightTerm,
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
            highlightTerm: args.highlightTerm,
            isIgnored: args.isIgnored,
            ignoredUsers: args.ignoredUsers,
          },
          decoratorState,
          cooked: this.cooked,
          createDetachedElement: this.#createDetachedElement,
          currentUser: this.currentUser,
          extraDecorators: this.extraDecorators,
          helper,
          highlightTerm: args.highlightTerm,
          ignoredUsers: args.ignoredUsers,
          isIgnored: args.isIgnored,
          owner,
          post: this.args.post,
          renderGlimmer: helper.renderGlimmer,
          renderNestedPostCookedHtml,
          streamElement: this.isStreamElement,
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
    });

    const cleanUpFns = applyHtmlDecorators(
      element,
      helper,
      this.isStreamElement ? STREAM_HTML_DECORATOR : NON_STREAM_HTML_DECORATOR
    );

    this.#pendingDecoratorCleanup.push(...cleanUpFns);
  }

  get className() {
    return this.args.className ?? "cooked";
  }

  get cooked() {
    if (this.isIgnored) {
      return i18n("post.ignored");
    }

    return this.args.cooked ?? this.args.post.cooked;
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
      @className={{this.className}}
      @decorate={{this.decorate}}
      @decorateArgs={{lazyHash
        highlightTerm=this.highlightTerm
        isIgnored=this.isIgnored
        ignoredUsers=this.ignoredUsers
      }}
      @html={{htmlSafe this.cooked}}
      @model={{@post}}
    />
  </template>
}

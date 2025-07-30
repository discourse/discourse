import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import curryComponent from "ember-curry-component";
import DecoratedHtml, {
  DETACHED_DOCUMENT,
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

const POST_COOKED_DECORATORS_BEFORE_ADOPT = [
  decorateQuoteControls,
  decorateLinkCounts,
  decorateSearchHighlight,
];

const POST_COOKED_DECORATORS_AFTER_ADOPT = [
  decorateMentions,
  decorateStatefulHtmlElements,
];

export default class PostCookedHtml extends Component {
  @service appEvents;
  @service currentUser;

  #pendingCleanup = {};
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
  decorateBeforeAdopt(element, helper, args) {
    const extraDecorators = this.extraDecorators;
    const decorators = [
      ...POST_COOKED_DECORATORS_BEFORE_ADOPT,
      ...extraDecorators,
    ];
    if (this.shouldAddSelectionBarrier) {
      decorators.push(decorateSelectionBarrier);
    }

    this.#decorate("beforeAdopt", {
      element,
      helper,
      decorators,
      extraDecorators,
      args,
      decorateCookedEvent: this.isStreamElement
        ? "decorate-post-cooked-element:before-adopt"
        : "decorate-non-stream-cooked-element",
    });
  }

  @bind
  decorateAfterAdopt(element, helper, args) {
    const extraDecorators = this.extraDecoratorsAfterAdopt;
    const decorators = [
      ...POST_COOKED_DECORATORS_AFTER_ADOPT,
      ...extraDecorators,
    ];

    this.#decorate("afterAdopt", {
      element,
      helper,
      decorators,
      extraDecorators,
      args,
      decorateCookedEvent: this.isStreamElement
        ? "decorate-post-cooked-element:after-adopt"
        : null,
    });
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

  get extraDecoratorsAfterAdopt() {
    return makeArray(this.args.extraDecoratorsAfterAdopt);
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

  #cleanupDecorations(filter) {
    const phases = makeArray(filter || Object.keys(this.#pendingCleanup));

    phases.forEach((phase) => {
      if (!this.#pendingCleanup[phase]?.length) {
        return;
      }

      this.#pendingCleanup[phase].forEach((teardown) => teardown());
      this.#pendingCleanup[phase] = [];
    });
  }

  #createDetachedElement(nodeName) {
    return DETACHED_DOCUMENT.createElement(nodeName);
  }

  #decorate(
    phase,
    { element, helper, decorators, extraDecorators, args, decorateCookedEvent }
  ) {
    this.#cleanupDecorations(phase);

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

        const decorationCleanup = decorator(element, {
          cooked: this.cooked,
          createDetachedElement: this.#createDetachedElement,
          currentUser: this.currentUser,
          decoratorState,
          extraDecorators: this.extraDecorators,
          helper,
          highlightTerm: args.highlightTerm,
          ignoredUsers: args.ignoredUsers,
          isIgnored: args.isIgnored,
          owner,
          post: this.args.post,
          renderGlimmer: helper.renderGlimmer,
          renderNestedPostCookedHtml: this.#renderNestedPostCookedHtml(helper, {
            args,
            decoratorState,
            decorators: extraDecorators,
            isStreamElement: this.isStreamElement,
            owner,
          }),
          streamElement: this.isStreamElement,
        });

        if (typeof decorationCleanup === "function") {
          if (!this.#pendingCleanup[phase]) {
            this.#pendingCleanup[phase] = [];
          }
          this.#pendingCleanup[phase].push(decorationCleanup);
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

    if (decorateCookedEvent) {
      try {
        this.appEvents.trigger(decorateCookedEvent, element, helper);
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
  }

  #renderNestedPostCookedHtml(
    helper,
    {
      args,
      decoratorState,
      decorators,
      decoratorsAfterAdopt,
      streamElement,
      owner,
    }
  ) {
    return (
      element,
      post,
      { extraDecorators, extraDecoratorsAfterAdopt, extraArguments }
    ) => {
      const nestedArguments = {
        ...extraArguments,
        post,
        decoratorState,
        streamElement,
        highlightTerm: args.highlightTerm,
        extraDecorators: [...decorators, ...makeArray(extraDecorators)],
        extraDecoratorsAfterAdopt: [
          ...decoratorsAfterAdopt,
          ...makeArray(extraDecoratorsAfterAdopt),
        ],
      };

      helper.renderGlimmer(
        element,
        curryComponent(PostCookedHtml, nestedArguments, owner)
      );
    };
  }

  <template>
    <DecoratedHtml
      @className={{this.className}}
      @decorate={{this.decorateBeforeAdopt}}
      @decorateAfterAdopt={{this.decorateAfterAdopt}}
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

import Component from "@glimmer/component";
import { untrack } from "@glimmer/validator";
import { htmlSafe, isHTMLSafe } from "@ember/template";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import helperFn from "discourse/helpers/helper-fn";

const detachedDocument = document.implementation.createHTMLDocument("detached");

/**
 * Reactively renders cooked HTML with decorations applied.
 */
export default class DecoratedHtml extends Component {
  renderGlimmerInfos = new TrackedArray();

  decoratedContent = helperFn((args, on) => {
    const cookedDiv = this.elementToDecorate;

    const helper = new DecorateHtmlHelper({
      renderGlimmerInfos: this.renderGlimmerInfos,
    });
    on.cleanup(() => helper.teardown());

    const decorateFn = this.args.decorate;
    untrack(() => decorateFn?.(cookedDiv, helper));

    document.adoptNode(cookedDiv);

    const afterAdoptDecorateFn = this.args.decorateAfterAdopt;
    untrack(() => afterAdoptDecorateFn?.(cookedDiv, helper));

    return cookedDiv;
  });

  get elementToDecorate() {
    const cooked = this.args.html || htmlSafe("");
    if (!isHTMLSafe(cooked)) {
      throw "@cooked must be an htmlSafe string";
    }
    const cookedDiv = detachedDocument.createElement("div");
    cookedDiv.innerHTML = cooked.toString();

    if (this.args.id) {
      cookedDiv.id = this.args.id;
    }

    if (this.args.className) {
      cookedDiv.className = this.args.className;
    }
    return cookedDiv;
  }

  <template>
    {{~this.decoratedContent~}}

    {{~#each this.renderGlimmerInfos as |info|~}}
      {{~#in-element info.element insertBefore=null~}}
        <info.component @data={{info.data}} />
      {{~/in-element~}}
    {{~/each~}}
  </template>
}

class DecorateHtmlHelper {
  constructor({ renderGlimmerInfos }) {
    this.renderGlimmerInfos = renderGlimmerInfos;
  }

  renderGlimmer(element, component, data) {
    const info = { element, component, data };
    this.renderGlimmerInfos.push(info);
  }

  getModel() {
    return null;
  }

  teardown() {
    this.renderGlimmerInfos.length = 0;
  }
}

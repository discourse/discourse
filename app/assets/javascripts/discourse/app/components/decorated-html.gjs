import Component from "@glimmer/component";
import { untrack } from "@glimmer/validator";
import { getOwner, setOwner } from "@ember/owner";
import { htmlSafe, isHTMLSafe } from "@ember/template";
import helperFn from "discourse/helpers/helper-fn";

const detachedDocument = document.implementation.createHTMLDocument("detached");

function createDetachedElement(nodeName) {
  return detachedDocument.createElement(nodeName);
}

/**
 * Reactively renders cooked HTML with decorations applied.
 */
export default class DecoratedHtml extends Component {
  decoratedContent = helperFn((args, on) => {
    const cooked = this.args.html || htmlSafe("");
    if (!isHTMLSafe(cooked)) {
      throw "@cooked must be an htmlSafe string";
    }

    const cookedDiv = createDetachedElement("div");
    cookedDiv.innerHTML = cooked.toString();

    if (this.args.id) {
      cookedDiv.id = this.args.id;
    }

    if (this.args.className) {
      cookedDiv.className = this.args.className;
    }

    const helper = new DecorateHtmlHelper({
      owner: getOwner(this),
    });

    on.cleanup(() => helper.teardown());

    const decorateFn = this.args.decorate;

    untrack(() => {
      decorateFn?.(cookedDiv, helper);
    });

    document.adoptNode(cookedDiv);

    return cookedDiv;
  });

  <template>
    {{this.decoratedContent}}
  </template>
}

class DecorateHtmlHelper {
  #renderGlimmerInfos = [];

  constructor({ owner }) {
    setOwner(this, owner);
  }

  get #renderGlimmerService() {
    return getOwner(this).lookup("service:render-glimmer");
  }

  renderGlimmer(element, component, data) {
    const info = {
      element,
      component,
      data,
    };
    this.#renderGlimmerInfos.push(info);
    this.#renderGlimmerService.add(info);
  }

  /**
   *
   */
  getModel() {
    return null;
  }

  teardown() {
    for (const info of this.#renderGlimmerInfos) {
      this.#renderGlimmerService.remove(info);
    }
  }
}

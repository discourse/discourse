import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe, isHTMLSafe } from "@ember/template";
import helperFn from "discourse/helpers/helper-fn";
import DecorateCookedHelper from "discourse/lib/decorate-cooked-helper";

const detachedDocument = document.implementation.createHTMLDocument("detached");

function createDetachedElement(nodeName) {
  return detachedDocument.createElement(nodeName);
}

/**
 * Renders cooked post HTML with decorations applied.
 */
export default class DecoratedCooked extends Component {
  @service appEvents;

  decoratedCookedContent = helperFn((args, on) => {
    const cooked = this.args.cooked || htmlSafe("");
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

    const decorateCookedHelper = new DecorateCookedHelper({
      owner: getOwner(this),
    });

    on.cleanup(() => decorateCookedHelper.teardown());

    this.appEvents.trigger(
      "decorate-non-stream-cooked-element",
      cookedDiv,
      decorateCookedHelper
    );

    document.adoptNode(cookedDiv);

    return cookedDiv;
  });

  <template>
    {{this.decoratedCookedContent}}
  </template>
}

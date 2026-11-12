import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

/**
 * One adoption, declared once. Adoption is resolved for the whole page, so two
 * targets naming the same kind must share the predicate that decides it.
 */
const WEB_LINK = {
  type: "web-link",
  match: ({ element }) => Boolean(element.closest("a[href]")),
};

export default class AdoptionExample extends Component {
  @tracked url;

  @action
  onDrop({ source }) {
    this.url = source.native.getURLs()[0];
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <p>
        <a href="https://www.discourse.org">{{i18n
            "styleguide.sections.drag_and_drop.a_link"
          }}</a>
      </p>

      <div
        class="styleguide-drag-and-drop__zone"
        {{dDragAndDropTarget
          adopts=WEB_LINK
          position="inside"
          onDrop=this.onDrop
        }}
      >{{i18n "styleguide.sections.drag_and_drop.drop_a_link"}}</div>

      <p class="styleguide-example__result">
        {{#if this.url}}
          {{this.url}}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}

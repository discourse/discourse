import Component from "@ember/component";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { modifier } from "ember-modifier";
import {
  disableBodyScroll,
  enableBodyScroll,
  locks,
} from "discourse/lib/body-scroll-lock";

@tagName("")
export default class SelectKitCollection extends Component {
  @service site;

  bodyScrollLock = modifier((element) => {
    if (!this.site.mobileView) {
      return;
    }

    const isChildOfLock = locks.some((lock) =>
      lock.targetElement.contains(element)
    );

    if (isChildOfLock) {
      disableBodyScroll(element);
    }

    return () => {
      if (isChildOfLock) {
        enableBodyScroll(element);
      }
    };
  });
}

{{#if this.collection.content.length}}
  <ul
    class="select-kit-collection"
    aria-live="polite"
    role="menu"
    {{this.bodyScrollLock}}
  >
    {{#each this.collection.content as |item index|}}
      {{component
        (component-for-row this.collection.identifier item this.selectKit)
        index=index
        item=item
        value=this.value
        selectKit=this.selectKit
      }}
    {{/each}}
  </ul>
{{/if}}
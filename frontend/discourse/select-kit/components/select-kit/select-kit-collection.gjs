/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { modifier } from "ember-modifier";
import componentForRow from "discourse/helpers/component-for-row";
import { getLockState, lock, unlock } from "discourse/lib/body-scroll-lock";
import { resolveComponent } from "discourse/select-kit/components/select-kit";

@tagName("")
export default class SelectKitCollection extends Component {
  @service site;

  bodyScrollLock = modifier((element) => {
    if (this.site.desktopView) {
      return;
    }

    const isChildOfLock = getLockState().lockedElements.some((locked) =>
      locked.targetElement.contains(element)
    );

    if (isChildOfLock) {
      lock(element);
    }

    return () => {
      if (isChildOfLock) {
        unlock(element);
      }
    };
  });

  <template>
    {{#if this.collection.content.length}}
      <ul
        class="select-kit-collection"
        aria-live="polite"
        role="menu"
        {{this.bodyScrollLock}}
      >
        {{#each this.collection.content as |item index|}}
          {{#let
            (resolveComponent
              this
              (componentForRow this.collection.identifier item this.selectKit)
            )
            as |RowComponent|
          }}
            <RowComponent
              @item={{item}}
              @index={{index}}
              @value={{this.value}}
              @selectKit={{this.selectKit}}
            />
          {{/let}}
        {{/each}}
      </ul>
    {{/if}}
  </template>
}

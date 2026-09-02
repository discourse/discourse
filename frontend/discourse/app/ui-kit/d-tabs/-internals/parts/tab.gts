import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import booleanString from "discourse/helpers/boolean-string";
import DConditionalInElement from "discourse/ui-kit/d-conditional-in-element";
import type { DTabsTabSignature } from "discourse/ui-kit/d-tabs/types";

/**
 * One declared tab: the strip button and the panel content, together.
 *
 * The button renders in place. The group portals the declaration block into
 * the tablist, so declaration order is strip order. While the tab is active,
 * its panel content portals into the group's tabpanel.
 */
export default class Tab extends Component<DTabsTabSignature> {
  get domId() {
    return this.args.tabs.tabDomIdFor(this.args.id);
  }

  get isActive() {
    return this.args.id === this.args.tabs.active;
  }

  /**
   * The only guard for a disabled tab. The keyboard engine refuses Enter
   * and Space but does not prevent them, so the browser still synthesizes
   * a click here.
   */
  @action
  click() {
    if (this.args.disabled) {
      return;
    }

    this.args.tabs.activate(this.args.id);
  }

  /**
   * Called from the template as a helper, because only the template knows
   * whether a label block was given.
   */
  @action
  checkLabel(hasLabelBlock: boolean) {
    this.args.tabs.checkTabLabel(this.args.id, this.args.label, hasLabelBlock);
  }

  <template>
    {{! Splattributes come first so the attributes below win. A consumer id
        or role would sever the ARIA pairing. }}
    <button
      class="d-tabs__tab"
      ...attributes
      type="button"
      id={{this.domId}}
      role="tab"
      data-d-tab={{@id}}
      aria-selected={{booleanString this.isActive omitFalse=false}}
      aria-controls={{@tabs.panelDomId}}
      aria-disabled={{if @disabled "true"}}
      {{on "click" this.click}}
      {{@tabs.registerTab @id}}
    >
      {{this.checkLabel (has-block "label")}}
      {{#if (has-block "label")}}{{yield to="label"}}{{else}}{{@label}}{{/if}}
    </button>

    {{#if this.isActive}}
      <DConditionalInElement @element={{@tabs.panelElement}} @append={{true}}>
        {{yield}}
      </DConditionalInElement>
    {{/if}}
  </template>
}

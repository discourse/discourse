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
 * the tablist, so declaration order is strip order. The panel content takes
 * the opposite trip: while the tab is active its block renders into the
 * group's persistent tabpanel, and unmounts when another tab takes over.
 */
export default class Tab extends Component<DTabsTabSignature> {
  get domId() {
    return this.args.tabs.tabDomIdFor(this.args.id);
  }

  get isActive() {
    return this.args.id === this.args.tabs.active;
  }

  /**
   * The only guard against pointer activation of a disabled tab: the
   * keyboard engine refuses Enter and Space on its own, but it leaves the
   * events un-prevented, so the browser still synthesizes a click.
   */
  @action
  click() {
    if (this.args.disabled) {
      return;
    }

    this.args.tabs.activate(this.args.id);
  }

  /**
   * Invoked as a helper so the template can hand over what the class cannot
   * see: whether a label block was given.
   */
  @action
  checkLabel(hasLabelBlock: boolean) {
    this.args.tabs.checkTabLabel(this.args.id, this.args.label, hasLabelBlock);
  }

  <template>
    {{! Splattributes come first so the structural attributes below them
        always win: a consumer id or role would otherwise sever the ARIA
        pairing the group derives from these. }}
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

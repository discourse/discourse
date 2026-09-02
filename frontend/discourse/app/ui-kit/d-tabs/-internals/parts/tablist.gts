import Component from "@glimmer/component";
import { and } from "discourse/truth-helpers";
import DOverflowControls from "discourse/ui-kit/d-overflow-controls";
import type { DTabsTablistSignature } from "discourse/ui-kit/d-tabs/types";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

/**
 * The tablist element: the keyboard surface and ARIA container the group's
 * tab buttons render into.
 *
 * It renders empty; the core portals the declaration block inside it, which
 * is what lets a `<:header>` block place this element anywhere while the
 * tabs still land in it. The tabs pattern's roles are withheld while no tab
 * is registered, because an empty tablist violates its required contents.
 */
export default class Tablist extends Component<DTabsTablistSignature> {
  get isVertical() {
    return this.args.tabs.orientation === "vertical";
  }

  <template>
    <DOverflowControls
      @axis={{@tabs.orientation}}
      @ownedScroller={{true}}
      @wrapperClass="d-tabs__strip-controls"
      as |strip|
    >
      {{! Splattributes come first so the role below stays authoritative. }}
      {{! The role is dynamic, so the linter only sees a bare div and would
          strip the orientation it cannot match to the tablist role. }}
      {{! eslint-disable-next-line ember/template-no-unsupported-role-attributes }}
      <div
        class="d-tabs__tablist"
        ...attributes
        role={{if @tabs.hasTabs "tablist"}}
        aria-label={{if @tabs.hasTabs @tabs.label}}
        aria-orientation={{if (and @tabs.hasTabs this.isVertical) "vertical"}}
        {{dRovingFocus
          orientation=@tabs.orientation
          itemSelector="[role='tab']"
          wrap=true
          itemsKey=@tabs.tabsVersion
          resetKey=@tabs.active
          disabledItems="focusable"
          onActivate=@tabs.activateFromElement
        }}
        {{@tabs.registerTablist}}
        {{strip.scroller}}
      ></div>
    </DOverflowControls>
  </template>
}

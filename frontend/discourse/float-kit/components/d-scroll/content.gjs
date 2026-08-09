import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import mergeScrollAttributes from "../../modifiers/merge-scroll-attributes";
import nativeFocusScrollPrevention from "./native-focus-scroll-prevention";

const registerContent = modifier((element, [controller]) => {
  controller.registerContent(element);

  return () => controller.unregisterContent(element);
});

function parentElement(element) {
  return element.parentElement;
}

export default class DScrollContent extends Component {
  get view() {
    return this.args.controller.viewOwner;
  }

  <template>
    <div
      data-d-scroll={{this.view.scrollContainerDataAttribute}}
      style={{this.view.combinedStyle}}
      tabindex={{this.view.computedTabIndex}}
      role={{this.view.computedRole}}
      {{this.view.syncScrollTrapState
        @controller
        this.view.scrollTrapX
        this.view.scrollTrapY
      }}
      {{this.view.registerElement
        onRegister=this.view.handleElementRegister
        onScroll=this.view.onScrollEvent
        onScrollEnd=this.view.onScrollEndEvent
        onFocusIn=this.view.onFocusInsideEvent
        onFocusOut=this.view.onBlurInsideEvent
        controller=@controller
        onUnregister=this.view.handleElementUnregister
      }}
      {{this.view.manageGestureTrap
        this.view.axis
        this.view.scrollGestureTrap
        this.view.pageScroll
      }}
      {{this.view.manageSafeArea
        this.view.axis
        this.view.safeArea
        this.view.sheet
      }}
      {{nativeFocusScrollPrevention this.view.shouldPreventNativeFocus}}
    >
      {{#if this.view.needsSwipeTrapObserver}}
        <div
          data-d-scroll={{this.view.startSpyDataScroll}}
          {{this.view.registerStartSpy
            register=this.view.registerStartSpyElement
            unregister=this.view.unregisterStartSpyElement
          }}
        ></div>
      {{/if}}
      {{#if this.view.shouldRenderSpacers}}
        <div
          data-d-scroll={{this.view.startSpacerDataScroll}}
          style={{this.view.spacerStyle}}
          {{this.view.registerStartSpacer
            register=this.view.registerStartSpacerElement
          }}
        ></div>
      {{/if}}
      <div
        {{registerContent @controller}}
        ...attributes
        {{mergeScrollAttributes
          "content"
          (if @controller.overflowX "overflow-x" "no-overflow-x")
          (if @controller.overflowY "overflow-y" "no-overflow-y")
          (if @controller.scrollTrapX "trap-x")
          (if @controller.scrollTrapY "trap-y")
          mirrorTargetTokens=this.view.scrollContainerDataAttribute
          mirrorTo=parentElement
        }}
      >
        {{yield}}
      </div>
      {{#if this.view.shouldRenderSpacers}}
        <div
          data-d-scroll={{this.view.endSpacerDataScroll}}
          style={{this.view.spacerStyle}}
          {{this.view.registerEndSpacer
            register=this.view.registerEndSpacerElement
          }}
        ></div>
      {{/if}}
      {{#if this.view.needsSwipeTrapObserver}}
        <div
          data-d-scroll={{this.view.endSpyDataScroll}}
          {{this.view.registerEndSpy
            register=this.view.registerEndSpyElement
            unregister=this.view.unregisterEndSpyElement
          }}
        ></div>
      {{/if}}
    </div>
  </template>
}

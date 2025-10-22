import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import curryComponent from "ember-curry-component";
import { modifier } from "ember-modifier";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { isTesting } from "discourse/lib/environment";
import DFloatBody from "float-kit/components/d-float-body";
import { MENU } from "float-kit/lib/constants";
import DMenuInstance from "float-kit/lib/d-menu-instance";

export default class DMenu extends Component {
  @service site;

  menuInstance = new DMenuInstance(getOwner(this), {
    ...this.allowedProperties,
    autoUpdate: true,
    listeners: true,
  });

  registerTrigger = modifier((domElement) => {
    this.menuInstance.trigger = domElement;
    this.options.onRegisterApi?.(this.menuInstance);

    return () => {
      this.menuInstance.destroy();
    };
  });

  registerFloatBody = modifier((domElement) => {
    this.body = domElement;

    return () => {
      this.body = null;
    };
  });

  @action
  teardownFloatBody() {
    this.body = null;
  }

  @action
  forwardTabToContent(event) {
    // need to call the parent handler to allow arrow key navigation to siblings in toolbar contexts
    const parentHandlerResult = this.args.onKeydown?.(event);

    if (!this.body) {
      return parentHandlerResult;
    }

    if (event.key === "Tab") {
      event.preventDefault();

      const firstFocusable = this.body.querySelector(
        'button, a, input:not([type="hidden"]), select, textarea, [tabindex]:not([tabindex="-1"])'
      );

      firstFocusable?.focus() || this.body.focus();
      return true;
    }

    return parentHandlerResult;
  }

  get options() {
    return this.menuInstance?.options ?? {};
  }

  get componentArgs() {
    return {
      close: this.menuInstance.close,
      show: this.menuInstance.show,
      data: this.options.data,
    };
  }

  get triggerComponent() {
    const instance = this;
    const baseArguments = {
      get icon() {
        return instance.args.icon;
      },
      get translatedLabel() {
        return instance.args.label;
      },
      get translatedAriaLabel() {
        return instance.args.ariaLabel;
      },
      get translatedTitle() {
        return instance.args.title;
      },
      get disabled() {
        return instance.args.disabled;
      },
      get isLoading() {
        return instance.args.isLoading;
      },
    };

    return (
      this.args.triggerComponent ||
      curryComponent(DButton, baseArguments, getOwner(this))
    );
  }

  get allowedProperties() {
    const properties = {};
    for (const [key, value] of Object.entries(MENU.options)) {
      properties[key] = this.args[key] ?? value;
    }
    return properties;
  }

  <template>
    <this.triggerComponent
      {{this.registerTrigger}}
      class={{concatClass
        "fk-d-menu__trigger"
        (if this.menuInstance.expanded "-expanded")
        (concat this.options.identifier "-trigger")
        @triggerClass
        @class
      }}
      id={{this.menuInstance.id}}
      data-identifier={{this.options.identifier}}
      data-trigger
      aria-expanded={{if this.menuInstance.expanded "true" "false"}}
      {{on "keydown" this.forwardTabToContent}}
      @componentArgs={{this.componentArgs}}
      ...attributes
    >
      {{#if (has-block "trigger")}}
        {{yield this.componentArgs to="trigger"}}
      {{/if}}
    </this.triggerComponent>

    {{#if this.menuInstance.expanded}}
      {{#if (and this.site.mobileView this.options.modalForMobile)}}
        <DModal
          @closeModal={{this.menuInstance.close}}
          @hideHeader={{true}}
          @autofocus={{this.options.autofocus}}
          class={{concatClass
            "fk-d-menu-modal"
            (concat this.options.identifier "-content")
            @contentClass
            @class
          }}
          @inline={{(isTesting)}}
          data-identifier={{this.options.identifier}}
          data-content
        >
          <div class="fk-d-menu-modal__grip" aria-hidden="true"></div>
          {{#if (has-block)}}
            {{yield this.componentArgs}}
          {{else if (has-block "content")}}
            {{yield this.componentArgs to="content"}}
          {{else if this.options.component}}
            <this.options.component
              @data={{this.options.data}}
              @close={{this.menuInstance.close}}
            />
          {{else if this.options.content}}
            {{this.options.content}}
          {{/if}}
        </DModal>
      {{else}}
        <DFloatBody
          @instance={{this.menuInstance}}
          @trapTab={{this.options.trapTab}}
          @mainClass={{concatClass
            "fk-d-menu"
            (concat this.options.identifier "-content")
            @class
            @contentClass
          }}
          @innerClass="fk-d-menu__inner-content"
          @role="dialog"
          @inline={{this.options.inline}}
          {{this.registerFloatBody}}
        >
          {{#if (has-block)}}
            {{yield this.componentArgs}}
          {{else if (has-block "content")}}
            {{yield this.componentArgs to="content"}}
          {{else if this.options.component}}
            <this.options.component
              @data={{this.options.data}}
              @close={{this.menuInstance.close}}
            />
          {{else if this.options.content}}
            {{this.options.content}}
          {{/if}}
        </DFloatBody>
      {{/if}}
    {{/if}}
  </template>
}

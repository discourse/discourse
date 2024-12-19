import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { isTesting } from "discourse-common/config/environment";
import DFloatBody from "float-kit/components/d-float-body";
import { MENU } from "float-kit/lib/constants";
import DMenuInstance from "float-kit/lib/d-menu-instance";

export default class DMenu extends Component {
  @service menu;
  @service site;

  menuInstance = new DMenuInstance(getOwner(this), {
    ...this.allowedProperties,
    autoUpdate: true,
    listeners: true,
  });

  registerTrigger = modifier((element) => {
    this.menuInstance.trigger = element;
    this.options.onRegisterApi?.(this.menuInstance);

    return () => {
      this.menuInstance.destroy();
    };
  });

  @action
  registerFloatBody(element) {
    this.body = element;
  }

  @action
  forwardTabToContent(event) {
    if (!this.body) {
      return;
    }

    if (event.key === "Tab") {
      event.preventDefault();

      const firstFocusable = this.body.querySelector(
        'button, a, input:not([type="hidden"]), select, textarea, [tabindex]:not([tabindex="-1"])'
      );

      firstFocusable?.focus() || this.body.focus();
    }
  }

  get menuId() {
    return `d-menu-${this.menuInstance.id}`;
  }

  get options() {
    return this.menuInstance?.options ?? {};
  }

  get componentArgs() {
    return {
      close: this.menuInstance.close,
      data: this.options.data,
    };
  }

  get allowedProperties() {
    const properties = {};
    for (const [key, value] of Object.entries(MENU.options)) {
      properties[key] = this.args[key] ?? value;
    }
    return properties;
  }

  <template>
    <DButton
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
      @icon={{@icon}}
      @translatedAriaLabel={{@ariaLabel}}
      @translatedLabel={{@label}}
      @translatedTitle={{@title}}
      @disabled={{@disabled}}
      @isLoading={{@isLoading}}
      aria-expanded={{if this.menuInstance.expanded "true" "false"}}
      {{on "keydown" this.forwardTabToContent}}
      ...attributes
    >
      {{#if (has-block "trigger")}}
        {{yield this.componentArgs to="trigger"}}
      {{/if}}
    </DButton>

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
          data-identifier={{@instance.options.identifier}}
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
          {{didInsert this.registerFloatBody}}
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

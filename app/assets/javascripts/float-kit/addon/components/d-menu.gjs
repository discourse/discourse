import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import DFloatBody from "float-kit/components/d-float-body";
import { MENU } from "float-kit/lib/constants";
import DMenuInstance from "float-kit/lib/d-menu-instance";

export default class DMenu extends Component {
  @service menu;

  @tracked menuInstance = null;

  registerTrigger = modifier((element, [properties]) => {
    const options = {
      ...properties,
      ...{
        autoUpdate: true,
        listeners: true,
        beforeTrigger: () => {
          this.menu.close();
        },
      },
    };
    const instance = new DMenuInstance(getOwner(this), element, options);

    this.menuInstance = instance;

    this.options.onRegisterApi?.(this.menuInstance);

    return () => {
      instance.destroy();

      if (this.isDestroying) {
        this.menuInstance = null;
      }
    };
  });

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

  @action
  allowedProperties() {
    const keys = Object.keys(MENU.options);
    return keys.reduce((result, key) => {
      result[key] = this.args[key];

      return result;
    }, {});
  }

  <template>
    <DButton
      class={{concatClass
        "fk-d-menu__trigger"
        (if this.menuInstance.expanded "-expanded")
        (concat this.options.identifier "-trigger")
      }}
      id={{this.menuInstance.id}}
      data-identifier={{this.options.identifier}}
      data-trigger
      @icon={{@icon}}
      @translatedAriaLabel={{@ariaLabel}}
      @translatedLabel={{@label}}
      @translatedTitle={{@title}}
      @disabled={{@disabled}}
      aria-expanded={{if this.menuInstance.expanded "true" "false"}}
      {{this.registerTrigger (this.allowedProperties)}}
      ...attributes
    >
      {{#if (has-block "trigger")}}
        {{yield this.componentArgs to="trigger"}}
      {{/if}}
    </DButton>

    {{#if this.menuInstance.expanded}}
      <DFloatBody
        @instance={{this.menuInstance}}
        @trapTab={{this.options.trapTab}}
        @mainClass={{concatClass
          "fk-d-menu"
          (concat this.options.identifier "-content")
        }}
        @innerClass="fk-d-menu__inner-content"
        @role="dialog"
        @inline={{this.options.inline}}
        @portalOutletElement={{this.menu.portalOutletElement}}
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
  </template>
}

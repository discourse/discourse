import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DFloatBody from "float-kit/components/d-float-body";
import concatClass from "discourse/helpers/concat-class";
import { getOwner } from "@ember/application";
import DMenuInstance from "float-kit/lib/d-menu-instance";

export default class DMenu extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
    <DButton
      class={{concatClass
        "fk-d-menu__trigger"
        (if this.menuInstance.expanded "-expanded")
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
      {{this.registerTrigger}}
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
        @mainClass="fk-d-menu"
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

  @service menu;

  @tracked menuInstance = null;

  registerTrigger = modifier((element) => {
    const options = {
      ...this.args,
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
      close: this.menu.close,
      data: this.options.data,
    };
  }
}

import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import curryComponent from "ember-curry-component";
import DMenu from "discourse/float-kit/components/d-menu";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
class Button extends Component {
  <template>
    {{#let (curryComponent DButton this.args) as |CurriedComponent|}}
      <CurriedComponent class="d-combo-button-button" ...attributes>
        {{yield}}
      </CurriedComponent>
    {{/let}}
  </template>
}

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
class Menu extends Component {
  <template>
    {{#let (curryComponent DMenu this.args) as |CurriedComponent|}}
      {{! The trigger sits at the group's trailing edge, so the float aligns
          there. Both defaults are written as fallbacks because invocation-site
          arguments beat curried ones, which would otherwise make them
          overrides. }}
      <CurriedComponent
        @icon={{or @icon "chevron-down"}}
        @placement={{or @placement "bottom-end"}}
        class="d-combo-button-menu"
        ...attributes
      >
        <:content>
          {{yield}}
        </:content>
      </CurriedComponent>
    {{/let}}
  </template>
}

const DComboButton = <template>
  <div class="d-combo-button" role="group" ...attributes>
    {{yield (hash Button=Button Menu=Menu)}}
  </div>
</template>;

export default DComboButton;

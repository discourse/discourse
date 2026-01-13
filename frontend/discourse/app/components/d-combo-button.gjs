import Component from "@glimmer/component";
import curryComponent from "ember-curry-component";
import DButton from "discourse/components/d-button";
import DMenu from "discourse/float-kit/components/d-menu";

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
      <CurriedComponent
        @icon="chevron-down"
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
  <div class="d-combo-button" ...attributes>
    {{yield Button Menu}}
  </div>
</template>;

export default DComboButton;

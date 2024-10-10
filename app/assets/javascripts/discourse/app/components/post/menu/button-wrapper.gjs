import Component from "@glimmer/component";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
export default class PostMenuButtonWrapper extends Component {
  // we need a class component because we need to pass this.args to the config helpers

  <template>
    <@buttonConfig.Component
      class="btn-flat"
      @alwaysShow={{@buttonConfig.alwaysShow this.args}}
      @buttonActions={{@buttonActions}}
      @context={{@context}}
      @post={{@post}}
      @shouldRender={{@buttonConfig.shouldRender this.args}}
      @showLabel={{@showLabel.showLabel this.args}}
    />
  </template>
}

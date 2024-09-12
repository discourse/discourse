import { cached } from "@glimmer/tracking";

export default class PostMenuButtonConfig {
  #key;
  #Component;
  #shouldRender;
  #position;
  #showLabel;
  #action;
  #secondaryAction;
  #actionMode;
  #alwaysShow;
  #context;
  #extraControls;
  #post;

  constructor(config, post) {
    this.#key = config.key;
    this.#Component = config.Component;
    this.#shouldRender = config.shouldRender;
    this.#position = config.position;
    this.#showLabel = config.showLabel;
    this.#action = config.action;
    this.#secondaryAction = config.secondaryAction;
    this.#actionMode = config.actionMode;
    this.#alwaysShow = config.alwaysShow;
    this.#context = config.context;
    this.#extraControls = config.extraControls;
    this.#post = post;
  }

  get key() {
    return this.#key;
  }

  get Component() {
    return this.#Component;
  }

  get position() {
    return this.#position;
  }

  get showLabel() {
    return this.#showLabel;
  }

  get action() {
    return this.#action;
  }

  get secondaryAction() {
    return this.#secondaryAction;
  }

  get actionMode() {
    return this.#actionMode;
  }

  get alwaysShow() {
    return this.#alwaysShow;
  }

  get extraControls() {
    return this.#extraControls;
  }

  @cached // context can be expensive
  get context() {
    if (typeof this.#context === "function") {
      return this.#context();
    }

    return this.#context;
  }

  get shouldRender() {
    if (typeof this.#shouldRender === "function") {
      return this.#shouldRender(this.#post, this.context);
    }

    return this.#shouldRender ?? true;
  }

  get PostMenuButtonComponent() {
    // we need to save the value of `this` context otherwise it will be overridden when
    // while Ember renders the component
    const buttonConfig = this;
    const post = this.#post;

    return <template>
      <buttonConfig.Component
        class="btn-flat"
        ...attributes
        @action={{buttonConfig.action}}
        @actionMode={{buttonConfig.actionMode}}
        @context={{buttonConfig.context}}
        @post={{post}}
        @secondaryAction={{buttonConfig.secondaryAction}}
        @shouldRender={{buttonConfig.shouldRender}}
        @showLabel={{buttonConfig.showLabel}}
      />
    </template>;
  }
}

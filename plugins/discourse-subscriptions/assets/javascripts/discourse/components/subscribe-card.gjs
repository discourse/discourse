import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

export default class SubscribeCard extends Component {
  @action
  setCardElementStyles() {
    this.args.cardElement.mount("#card-element");

    const computedStyle = getComputedStyle(document.documentElement);

    this.args.cardElement.update({
      style: {
        base: {
          color: computedStyle.getPropertyValue("--primary"),
          "::placeholder": {
            color: computedStyle.getPropertyValue("--secondary-medium"),
          },
        },
      },
    });
  }

  <template>
    <div
      {{didInsert this.setCardElementStyles}}
      id="card-element"
      ...attributes
    ></div>
  </template>
}

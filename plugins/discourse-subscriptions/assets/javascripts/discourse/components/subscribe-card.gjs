import Component from "@ember/component";

export default class SubscribeCard extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);
    this.cardElement.mount("#card-element");
    this.setCardElementStyles();
  }

  setCardElementStyles() {
    const root = document.querySelector(":root");
    const computedStyle = getComputedStyle(root);
    const primaryColor = computedStyle.getPropertyValue("--primary");
    const placeholderColor =
      computedStyle.getPropertyValue("--secondary-medium");
    this.cardElement.update({
      style: {
        base: {
          color: primaryColor,
          "::placeholder": {
            color: placeholderColor,
          },
        },
      },
    });
  }

  didDestroyElement() {
    super.didDestroyElement(...arguments);
  }

  <template>
    <div id="card-element"></div>
  </template>
}

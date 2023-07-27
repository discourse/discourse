import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class AiSummarySkeleton extends Component {
  intId = null;

  @action
  startAnimation(element) {
    let ulSize = 20;
    let index = 0;

    const elements = element.getElementsByTagName("li");

    const show = () => {
      let liElement = elements[index];
      if (liElement && index < ulSize) {
        liElement.classList.remove("blink");
        liElement.classList.add("show");
        liElement.classList.add("is-shown");
        index++;
      } else if (index === ulSize) {
        index = 0;
        clearInterval(this.intId);
        this.intId = setInterval(() => blink(), 250);
      }
    };

    const blink = () => {
      let liElement = elements[index];
      if (liElement && index < ulSize) {
        liElement.classList.remove("show");
        liElement.classList.add("blink");
        index++;
      } else if (index === ulSize) {
        for (let i = 0; i <= elements.length - 1; i++) {
          elements[i].classList.remove("blink");
        }
        index = 0;
      }
    };

    this.intId = setInterval(() => show(), 250);
  }

  @action
  stopAnimation() {
    clearInterval(this.intId);
  }
}

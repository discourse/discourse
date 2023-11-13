import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class ChatSkeleton extends Component {
  get placeholders() {
    return Array.from({ length: 15 }, () => {
      return {
        image: this.#randomIntFromInterval(1, 10) === 5,
        rows: Array.from({ length: this.#randomIntFromInterval(1, 5) }, () => {
          return htmlSafe(`width: ${this.#randomIntFromInterval(20, 95)}%`);
        }),
        reactions: Array.from({ length: this.#randomIntFromInterval(0, 3) }),
      };
    });
  }

  #randomIntFromInterval(min, max) {
    return Math.floor(Math.random() * (max - min + 1) + min);
  }
}

import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default class Reltime extends Component {
  get boundDateReplacement() {
    return htmlSafe(
      autoUpdatingRelativeAge(new Date(this.args.ctx.value), { title: true })
    );
  }

  <template>{{this.boundDateReplacement}}</template>
}

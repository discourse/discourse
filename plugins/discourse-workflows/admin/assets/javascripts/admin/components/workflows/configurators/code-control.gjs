import Component from "@glimmer/component";

export default class CodeControl extends Component {
  get height() {
    return this.args.schema?.ui?.height;
  }

  get lang() {
    return this.args.schema?.ui?.lang || "text";
  }

  <template>
    <div class="workflows-code-control">
      <@field.Control @height={{this.height}} @lang={{this.lang}} />
    </div>
  </template>
}

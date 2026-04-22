import Component from "@glimmer/component";

export default class CodeControl extends Component {
  get height() {
    return this.args.schema?.control_options?.height;
  }

  get lang() {
    return this.args.schema?.control_options?.lang || "text";
  }

  <template>
    <div class="workflows-code-control">
      <@field.Control @height={{this.height}} @lang={{this.lang}} />
    </div>
  </template>
}

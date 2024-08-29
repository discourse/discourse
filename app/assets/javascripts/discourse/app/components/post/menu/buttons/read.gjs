import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class PostMenuReadButton extends Component {
  get shouldRender() {
    return this.args.post.showReadIndicator && this.args.post.readCount > 0;
  }

  <template>
    {{#if this.shouldRender}}
      <DButton @action={{@action}} @title="post.controls.read_indicator">
        {{@post.readCount}}
      </DButton>
    {{/if}}
  </template>
}

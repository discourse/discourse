/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class ReviewableField extends Component {
  <template>
    <div ...attributes>
      {{#if this.value}}
        <div class={{this.classes}}>
          <div class="name">{{this.name}}</div>
          <div class="value">{{this.value}}</div>
        </div>
      {{/if}}
    </div>
  </template>
}

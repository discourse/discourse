import Component from "@ember/component";

export default class ReviewableField extends Component {
  <template>
    {{#if this.value}}
      <div class={{this.classes}}>
        <div class="name">{{this.name}}</div>
        <div class="value">{{this.value}}</div>
      </div>
    {{/if}}
  </template>
}

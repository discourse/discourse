import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class ErrorsCollection extends Component {
  <template>
    {{#if this.collection.content}}
      <ul class="select-kit-errors-collection">
        {{#each this.collection.content as |item|}}
          <li class="select-kit-error">{{item}}</li>
        {{/each}}
      </ul>
    {{/if}}
  </template>
}

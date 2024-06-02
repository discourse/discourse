import Component from "@glimmer/component";
import { concat } from "@ember/helper";

export default class MyDebug extends Component {
  <template>
    <ul>
      {{#each-in @value as |key value|}}
        <li>{{concat key ": " value}}</li>
      {{/each-in}}
    </ul>
  </template>
}

import Component from "@glimmer/component";

export default class AdminConfigAreasAbout extends Component {
  cards = [1, 2, 3];

  <template>
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        {{#each this.cards as |card|}}
          <div>{{card}}</div>
        {{/each}}
      </div>
    </div>
  </template>
}

import Component from "@glimmer/component";

export default class GroupsInfo extends Component {
  get showFullName() {
    return this.args.group?.full_name?.length;
  }

  <template>
    <span class="group-info-details">
      {{#if this.showFullName}}
        <span class="groups-info-name">{{@group.full_name}}</span>
      {{else}}
        <span class="groups-info-name">{{@group.displayName}}</span>
      {{/if}}
    </span>
  </template>
}

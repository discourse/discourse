import Component from "@glimmer/component";

export default class GroupLink extends Component {
  get name() {
    return this.args.name || this.args.group?.name;
  }

  get href() {
    return this.args.href || this.args.group?.url;
  }

  <template>
    <a
      ...attributes
      class="user-group trigger-group-card"
      data-group-card={{this.name}}
      href={{this.href}}
    >
      {{yield}}
    </a>
  </template>
}

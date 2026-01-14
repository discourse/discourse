import Component from "@glimmer/component";

export default class EnumInfo extends Component {
  get enuminfo() {
    return Object.entries(this.args.col.enum).map(([value, name]) => ({
      value,
      name,
    }));
  }

  <template>
    <ol>
      {{#each this.enuminfo as |enum|}}
        <li value={{enum.value}}>
          {{enum.name}}
        </li>
      {{/each}}
    </ol>
  </template>
}

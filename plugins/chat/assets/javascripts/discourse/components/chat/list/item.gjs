import Component from "@glimmer/component";

export default class Item extends Component {
  <template>
    {{yield @item}}
  </template>
}

import Component from "@glimmer/component";

export default class EmptyState extends Component {
  <template>
    <div class="c-list-empty-state" ...attributes>
      {{yield}}
    </div>
  </template>
}

import Component from "@ember/component";

export default class PopupMenu extends Component {}

<h3>{{i18n this.title}}</h3>
<ul>
  {{yield}}
</ul>
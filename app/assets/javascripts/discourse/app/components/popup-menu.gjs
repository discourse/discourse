import Component from "@ember/component";
import iN from "discourse/helpers/i18n";

export default class PopupMenu extends Component {<template><h3>{{iN this.title}}</h3>
<ul>
  {{yield}}
</ul></template>}

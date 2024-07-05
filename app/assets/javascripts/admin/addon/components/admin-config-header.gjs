import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class AdminFlagItem extends Component {
  get headerCssClass() {
    return `admin-${this.args.name}__header`;
  }
  <template>
    <div class={{this.headerCssClass}}>
      <h2>{{i18n @heading}}</h2>
      {{#if @primaryActionRoute}}
        <LinkTo
          @route={{@primaryActionRoute}}
          class={{concatClass
            "btn-primary"
            "btn"
            "btn-icon-text"
            @primaryActionCssClass
          }}
        >
          {{dIcon @primaryActionIcon}}
          {{i18n @primaryActionLabel}}
        </LinkTo>
      {{/if}}

      {{#if @subheading}}
        <h3>{{i18n @subheading}}</h3>
      {{/if}}
    </div>
  </template>
}

import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="container cakeday">
      <ul class="nav-pills">
        {{#if @controller.cakedayEnabled}}
          <li class="nav-item-anniversaries">
            <LinkTo @route="cakeday.anniversaries">
              {{i18n "anniversaries.title"}}
            </LinkTo>
          </li>
        {{/if}}

        {{#if @controller.birthdayEnabled}}
          <li class="nav-item-birthdays">
            <LinkTo @route="cakeday.birthdays">
              {{i18n "birthdays.title"}}
            </LinkTo>
          </li>
        {{/if}}
      </ul>

      {{outlet}}
    </div>
  </template>
);

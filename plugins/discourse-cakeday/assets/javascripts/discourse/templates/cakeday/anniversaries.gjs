import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="anniversaries">
      <ul class="nav-pills">
        <li>
          <LinkTo @route="cakeday.anniversaries.today">
            {{i18n "cakeday.today"}}
          </LinkTo>
        </li>

        <li>
          <LinkTo @route="cakeday.anniversaries.tomorrow">
            {{i18n "cakeday.tomorrow"}}
          </LinkTo>
        </li>

        <li>
          <LinkTo @route="cakeday.anniversaries.upcoming">
            {{i18n "cakeday.upcoming"}}
          </LinkTo>
        </li>

        <li>
          <LinkTo @route="cakeday.anniversaries.all">
            {{i18n "cakeday.all"}}
          </LinkTo>
        </li>
      </ul>

      {{outlet}}
    </div>
  </template>
);

import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class PoweredByDiscourse extends Component {
  get encodedDomain() {
    return btoa(window.location.hostname);
  }

  <template>
    <a
      class="powered-by-discourse"
      href="https://discover.discourse.org/powered-by/{{this.encodedDomain}}"
      nofollow="true"
    >
      <span class="powered-by-discourse__content">
        <span class="powered-by-discourse__logo">
          {{icon "fab-discourse"}}
        </span>
        <span>{{i18n "powered_by_discourse"}}</span>
      </span>
    </a>
  </template>
}

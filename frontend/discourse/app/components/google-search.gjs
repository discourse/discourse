/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed, set } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

@tagName("")
export default class GoogleSearch extends Component {
  @computed("siteSettings.login_required")
  get hidden() {
    return this.siteSettings?.login_required;
  }

  set hidden(value) {
    set(this, "siteSettings.login_required", value);
  }

  @computed
  get siteUrl() {
    return `${location.protocol}//${location.host}${getURL("/")}`;
  }

  <template>
    <div
      class={{concatClass "google-search-form" (if this.hidden "hidden")}}
      ...attributes
    >
      <PluginOutlet
        @name="google-search"
        @outletArgs={{lazyHash searchTerm=this.searchTerm siteUrl=this.siteUrl}}
        @defaultGlimmer={{true}}
      >
        <form
          action="//google.com/search"
          id="google-search"
          class="inline-form"
        >
          <input
            type="text"
            name="q"
            aria-label={{i18n "search.search_google"}}
            value={{@searchTerm}}
          />
          <input name="as_sitesearch" value={{@siteUrl}} type="hidden" />
          <button class="btn btn-primary" type="submit">{{i18n
              "search.search_google_button"
            }}</button>
        </form>
      </PluginOutlet>
    </div>
  </template>
}

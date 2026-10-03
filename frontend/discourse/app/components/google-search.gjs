import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class GoogleSearch extends Component {
  @service siteSettings;

  get hidden() {
    return this.siteSettings.login_required;
  }

  get siteUrl() {
    return `${location.protocol}//${location.host}${getURL("/")}`;
  }

  <template>
    <div
      class={{dConcatClass "google-search-form" (if this.hidden "hidden")}}
      ...attributes
    >
      <PluginOutlet
        @defaultGlimmer={{true}}
        @name="google-search"
        @outletArgs={{lazyHash searchTerm=@searchTerm siteUrl=this.siteUrl}}
      >
        <form
          action="//google.com/search"
          class="inline-form"
          id="google-search"
        >
          <input
            aria-label={{i18n "search.search_google"}}
            name="q"
            type="text"
            value={{@searchTerm}}
          />
          <input name="as_sitesearch" type="hidden" value={{this.siteUrl}} />
          <button class="btn btn-primary" type="submit">{{i18n
              "search.search_google_button"
            }}</button>
        </form>
      </PluginOutlet>
    </div>
  </template>
}

import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

@classNames("google-search-form")
@classNameBindings("hidden:hidden")
export default class GoogleSearch extends Component {
  @alias("siteSettings.login_required") hidden;

  @discourseComputed
  siteUrl() {
    return `${location.protocol}//${location.host}${getURL("/")}`;
  }

  <template>
    <PluginOutlet
      @name="google-search"
      @outletArgs={{lazyHash searchTerm=this.searchTerm siteUrl=this.siteUrl}}
      @defaultGlimmer={{true}}
    >
      <form action="//google.com/search" id="google-search" class="inline-form">
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
  </template>
}

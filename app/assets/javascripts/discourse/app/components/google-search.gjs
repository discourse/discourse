import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import iN from "discourse/helpers/i18n";

@classNames("google-search-form")
@classNameBindings("hidden:hidden")
export default class GoogleSearch extends Component {<template><form action="//google.com/search" id="google-search" class="inline-form">
  <input type="text" name="q" aria-label={{iN "search.search_google"}} value={{this.searchTerm}} />
  <input name="as_sitesearch" value={{this.siteUrl}} type="hidden" />
  <button class="btn btn-primary" type="submit">{{iN "search.search_google_button"}}</button>
</form></template>
  @alias("siteSettings.login_required") hidden;

  @discourseComputed
  siteUrl() {
    return `${location.protocol}//${location.host}${getURL("/")}`;
  }
}

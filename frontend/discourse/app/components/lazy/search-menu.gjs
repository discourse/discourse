import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "discourse/lib/service";
import SearchService from "discourse/services/search";
import { or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import { i18n } from "discourse-i18n";

let load;

// A plain input stands in for the search menu until the pointer reaches it,
// then the real menu takes over and keeps the focus.
export default class LazySearchMenu extends Component {
  @service(() => SearchService) search;

  @tracked wanted = false;

  get component() {
    return (load ??= import("discourse/components/search-menu"));
  }

  @action
  want() {
    this.wanted = true;
  }

  @action
  focusReal() {
    document.getElementById(this.args.searchInputId)?.focus();
  }

  <template>
    {{#if this.wanted}}
      <DAsyncContent @asyncData={{this.component}}>
        <:loading></:loading>
        <:content as |module|>
          <div class="lazy-search-menu" {{didInsert this.focusReal}}>
            <module.default
              @hideResults={{@hideResults}}
              @location={{@location}}
              @searchInputId={{@searchInputId}}
              @searchInputPlaceholder={{@searchInputPlaceholder}}
            />
          </div>
        </:content>
      </DAsyncContent>
    {{else}}
      <div
        class="search-menu-container search-input-wrapper"
        {{on "pointerenter" this.want}}
        {{on "touchstart" this.want passive=true}}
        {{on "focusin" this.want}}
      >
        <div class="search-input">
          <input
            id={{@searchInputId}}
            class="search-term__input"
            type="search"
            autocomplete="off"
            placeholder={{i18n (or @searchInputPlaceholder "search.title")}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}

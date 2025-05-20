import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";

export default class DiscoveryFilterNavigation extends Component {
  @service site;

  @tracked copyIcon = "link";
  @tracked copyClass = "btn-default";
  @resettableTracked newQueryString = this.args.queryString;

  @bind
  updateQueryString(string) {
    this.newQueryString = string;
  }

  @action
  clearInput() {
    this.newQueryString = "";
    this.args.updateTopicsListQueryParams(this.newQueryString);
  }

  @action
  copyQueryString() {
    this.copyIcon = "check";
    this.copyClass = "btn-default ok";

    navigator.clipboard.writeText(window.location);

    discourseDebounce(this._restoreButton, 3000);
  }

  @bind
  _restoreButton() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    this.copyIcon = "link";
    this.copyClass = "btn-default";
  }

  <template>
    {{bodyClass "navigation-filter"}}

    <section class="navigation-container">
      <div class="topic-query-filter">
        {{#if (and this.site.mobileView @canBulkSelect)}}
          <div class="topic-query-filter__bulk-action-btn">
            <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
          </div>
        {{/if}}

        <div class="topic-query-filter__input">
          {{icon "filter" class="topic-query-filter__icon"}}
          <Input
            class="topic-query-filter__filter-term"
            @value={{this.newQueryString}}
            @enter={{fn @updateTopicsListQueryParams this.newQueryString}}
            @type="text"
            id="queryStringInput"
            autocomplete="off"
          />
          {{! EXPERIMENTAL OUTLET - don't use because it will be removed soon  }}
          <PluginOutlet
            @name="below-filter-input"
            @outletArgs={{lazyHash
              updateQueryString=this.updateQueryString
              newQueryString=this.newQueryString
            }}
          />
        </div>
        {{#if this.newQueryString}}
          <div class="topic-query-filter__controls">
            <DButton
              @icon="xmark"
              @action={{this.clearInput}}
              @disabled={{unless this.newQueryString "true"}}
            />

            {{#if this.discoveryFilter.q}}
              <DButton
                @icon={{this.copyIcon}}
                @action={{this.copyQueryString}}
                @disabled={{unless this.newQueryString "true"}}
                class={{this.copyClass}}
              />
            {{/if}}
          </div>
        {{/if}}
      </div>
    </section>
  </template>
}

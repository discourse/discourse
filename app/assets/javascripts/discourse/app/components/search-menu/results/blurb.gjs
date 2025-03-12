import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class Blurb extends Component {
  @service siteSettings;
  @service site;
}

<span class="blurb">
  {{format-age @result.created_at}}
  <span class="blurb__separator"> - </span>
  {{#if this.siteSettings.use_pg_headlines_for_excerpt}}
    <span>{{html-safe @result.blurb}}</span>
  {{else}}
    <span class="blurb__text">
      <SearchMenu::HighlightedSearch @string={{@result.blurb}} />
    </span>
  {{/if}}
</span>
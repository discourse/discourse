import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import AboutPage from "discourse/components/about-page";

export default class ContextAbout extends Component {
  @service about;
  @service pageShell;
  @service siteSettings;

  get model() {
    return this.about.data?.about;
  }

  @action
  loadAbout() {
    return this.about.load().catch(() => {});
  }

  <template>
    {{#if this.pageShell.canOpenContext}}
      <div class="context-about" {{didInsert this.loadAbout}}>
        {{#if this.model}}
          <AboutPage @inContext={{true}} @model={{this.model}} />
        {{else}}
          <h2>{{this.siteSettings.title}}</h2>
          {{#if this.siteSettings.short_site_description}}
            <p>{{this.siteSettings.short_site_description}}</p>
          {{/if}}
        {{/if}}

      </div>
    {{/if}}
  </template>
}

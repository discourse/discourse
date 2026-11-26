import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import AboutSiteActivity from "discourse/components/about-site-activity";
import ContextCategoryNavigation from "discourse/components/page-shell/context-category-navigation";
import PoweredByDiscourse from "discourse/components/powered-by-discourse";
import { i18n } from "discourse-i18n";

export default class ContextAbout extends Component {
  @service about;
  @service siteSettings;

  get model() {
    return this.about.data?.about;
  }

  get description() {
    return this.siteSettings.short_site_description || this.model?.description;
  }

  get contactHref() {
    const url = this.model?.contact_url;
    if (url) {
      return url.startsWith("/") || /^https?:/i.test(url) ? url : `//${url}`;
    }

    if (this.model?.contact_email) {
      return `mailto:${this.model.contact_email}`;
    }
  }

  @action
  loadAbout() {
    return this.about.load().catch(() => {});
  }

  <template>
    <ContextCategoryNavigation />
    <section
      aria-label={{i18n "about.simple_title"}}
      class="context-about"
      {{didInsert this.loadAbout}}
    >
      {{#if this.description}}
        <p class="context-about__description">{{this.description}}</p>
      {{/if}}
      <AboutSiteActivity @model={{this.model}} />
      {{#if this.contactHref}}
        <h2>{{i18n "about.contact"}}</h2>
        <a href={{this.contactHref}}>
          {{or this.model.contact_url this.model.contact_email}}
        </a>
      {{/if}}
      {{#if this.siteSettings.enable_powered_by_discourse}}
        <div class="context-about__attribution">
          <PoweredByDiscourse @inContext={{true}} />
        </div>
      {{/if}}
    </section>
  </template>
}

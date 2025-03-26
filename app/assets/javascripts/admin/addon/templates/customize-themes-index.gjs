import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="themes-intro admin-intro">
      <img src={{@controller.womanArtistEmojiURL}} alt />
      <div class="content-wrapper">
        <h1>{{i18n "admin.customize.theme.themes_intro"}}</h1>
        <div class="create-actions">
          <DButton
            @action={{routeAction "installModal"}}
            @icon="upload"
            @label="admin.customize.install"
            class="btn-primary"
          />
        </div>
        <div class="external-resources">
          {{#each @controller.externalResources as |resource|}}
            <a
              href={{resource.link}}
              class="external-link"
              rel="noopener noreferrer"
              target="_blank"
            >
              {{icon resource.icon}}
              {{i18n resource.key}}
            </a>
          {{/each}}
        </div>
      </div>
    </div>
  </template>
);

import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";
import StyleguideSection from "discourse/plugins/styleguide/discourse/components/styleguide-section";

export default RouteTemplate(
  <template>
    <StyleguideSection @title="styleguide.title">
      <div class="description">
        {{i18n "styleguide.welcome"}}
      </div>
    </StyleguideSection>
  </template>
);

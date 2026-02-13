import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";
import StyleguideLink from "discourse/plugins/styleguide/discourse/components/styleguide-link";
import ThemeBuilderToggleButton from "discourse/plugins/styleguide/discourse/components/theme-builder/toggle-button";
import ToggleColorMode from "discourse/plugins/styleguide/discourse/components/toggle-color-mode";

export default <template>
  <section class="styleguide">
    <section class="styleguide-menu">
      <ToggleColorMode />
      <ThemeBuilderToggleButton />

      {{#each @controller.categories as |c|}}
        <ul>
          <li class="styleguide-heading">
            {{i18n (concat "styleguide.categories." c.id)}}
          </li>
          {{#each c.sections as |s|}}
            <li><StyleguideLink @section={{s}} /></li>
          {{/each}}
        </ul>
      {{/each}}
    </section>

    <section class="styleguide-contents">
      {{outlet}}
    </section>
  </section>
</template>

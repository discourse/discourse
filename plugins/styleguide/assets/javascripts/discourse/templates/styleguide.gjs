import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";
import CssVariableEditor from "discourse/plugins/styleguide/discourse/components/css-variable-editor";
import StyleguideLink from "discourse/plugins/styleguide/discourse/components/styleguide-link";

export default <template>
  <section class="styleguide">
    <section class="styleguide-menu">
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

    <CssVariableEditor />
  </section>
</template>

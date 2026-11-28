import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import IconExample from "../../examples/atoms/pill/icon.gjs";
import iconSource from "../../examples/atoms/pill/icon?source=file";
import InContextExample from "../../examples/atoms/pill/in-context.gjs";
import inContextSource from "../../examples/atoms/pill/in-context?source=file";
import TypesExample from "../../examples/atoms/pill/types.gjs";
import typesSource from "../../examples/atoms/pill/types?source=file";

const KEY = "styleguide.sections.pill";

export default <template>
  <p class="section-description">
    {{i18n (concat KEY ".description")}}
  </p>

  <StyleguideExample
    @code={{typesSource}}
    @description={{i18n (concat KEY ".types_description")}}
    @kind="component"
    @note={{i18n (concat KEY ".types_note")}}
    @title={{i18n (concat KEY ".types_example")}}
  >
    <TypesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{iconSource}}
    @description={{i18n (concat KEY ".icon_description")}}
    @kind="component"
    @title={{i18n (concat KEY ".icon_example")}}
  >
    <IconExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{inContextSource}}
    @description={{i18n (concat KEY ".context_description")}}
    @kind="component"
    @title={{i18n (concat KEY ".context_example")}}
    @tryThis={{i18n (concat KEY ".context_try_this")}}
  >
    <InContextExample />
  </StyleguideExample>
</template>

import { i18n } from "discourse-i18n";
import ContextMenuDecliningExample from "../../examples/molecules/context-menu/declining.gjs";
import contextMenuDecliningSource from "../../examples/molecules/context-menu/declining?source=file";
import ContextMenuNestingExample from "../../examples/molecules/context-menu/nesting.gjs";
import contextMenuNestingSource from "../../examples/molecules/context-menu/nesting?source=file";
import StyleguideExample from "../../styleguide-example.gjs";

/**
 * Demos for the context-menu modifier: what a right-click opens, and what happens when a
 * handler declines it.
 *
 * Both examples use ordinary surfaces rather than a real editor, so anything that misbehaves
 * here is the modifier rather than a component wrapped around it.
 */
export default <template>
  <p class="section-description">
    {{i18n "styleguide.sections.context_menu.description"}}
  </p>

  <StyleguideExample
    @code={{contextMenuNestingSource}}
    @description={{i18n
      "styleguide.sections.context_menu.nesting.example_description"
    }}
    @kind="modifier"
    @note={{i18n "styleguide.sections.context_menu.nesting.note"}}
    @title={{i18n "styleguide.sections.context_menu.nesting.example"}}
    @tryThis={{i18n "styleguide.sections.context_menu.nesting.try_this"}}
  >
    <ContextMenuNestingExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{contextMenuDecliningSource}}
    @description={{i18n
      "styleguide.sections.context_menu.declining.example_description"
    }}
    @kind="modifier"
    @note={{i18n "styleguide.sections.context_menu.declining.note"}}
    @title={{i18n "styleguide.sections.context_menu.declining.example"}}
    @tryThis={{i18n "styleguide.sections.context_menu.declining.try_this"}}
  >
    <ContextMenuDecliningExample />
  </StyleguideExample>
</template>

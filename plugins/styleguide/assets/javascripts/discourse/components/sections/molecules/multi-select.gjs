import { i18n } from "discourse-i18n";
import MultiSelectExample from "../../examples/molecules/multi-select.gjs";
import multiSelectSource from "../../examples/molecules/multi-select?source=file";
import EmptyFooterExample from "../../examples/molecules/multi-select-footer-empty.gjs";
import emptyFooterSource from "../../examples/molecules/multi-select-footer-empty?source=file";
import ScrollFooterExample from "../../examples/molecules/multi-select-footer-scroll.gjs";
import scrollFooterSource from "../../examples/molecules/multi-select-footer-scroll?source=file";
import StyleguideComponent from "../../styleguide/component.gjs";
import StyleguideExample from "../../styleguide-example.gjs";

export default <template>
  <StyleguideExample @code={{multiSelectSource}} @title="<DMultiSelect />">
    <StyleguideComponent @tag="d-multi-select component">
      <:sample>
        <MultiSelectExample />
      </:sample>
    </StyleguideComponent>
  </StyleguideExample>
  <StyleguideExample
    @code={{emptyFooterSource}}
    @description={{i18n
      "styleguide.sections.multi_select.footer_empty_description"
    }}
    @title={{i18n "styleguide.sections.multi_select.footer_empty_title"}}
    @tryThis={{i18n "styleguide.sections.multi_select.footer_empty_try_this"}}
  >
    <StyleguideComponent @tag="d-multi-select footer">
      <:sample>
        <EmptyFooterExample />
      </:sample>
    </StyleguideComponent>
  </StyleguideExample>
  <StyleguideExample
    @code={{scrollFooterSource}}
    @description={{i18n
      "styleguide.sections.multi_select.footer_scroll_description"
    }}
    @title={{i18n "styleguide.sections.multi_select.footer_scroll_title"}}
    @tryThis={{i18n "styleguide.sections.multi_select.footer_scroll_try_this"}}
  >
    <StyleguideComponent @tag="d-multi-select footer">
      <:sample>
        <ScrollFooterExample />
      </:sample>
    </StyleguideComponent>
  </StyleguideExample>
</template>

import { i18n } from "discourse-i18n";
import ChipIconsSelectExample from "../../examples/molecules/select/content/chip-icons";
import chipIconsSelectSource from "../../examples/molecules/select/content/chip-icons?source=file";
import ComputedSelectExample from "../../examples/molecules/select/content/computed";
import computedSelectSource from "../../examples/molecules/select/content/computed?source=file";
import DefaultsSelectExample from "../../examples/molecules/select/content/defaults";
import defaultsSelectSource from "../../examples/molecules/select/content/defaults?source=file";
import DividerSelectExample from "../../examples/molecules/select/content/divider";
import dividerSelectSource from "../../examples/molecules/select/content/divider?source=file";
import CustomEmptySelectExample from "../../examples/molecules/select/content/empty";
import customEmptySelectSource from "../../examples/molecules/select/content/empty?source=file";
import CustomErrorSelectExample from "../../examples/molecules/select/content/error";
import customErrorSelectSource from "../../examples/molecules/select/content/error?source=file";
import FooterSelectExample from "../../examples/molecules/select/content/footer";
import footerSelectSource from "../../examples/molecules/select/content/footer?source=file";
import GroupedSelectExample from "../../examples/molecules/select/content/grouped";
import groupedSelectSource from "../../examples/molecules/select/content/grouped?source=file";
import RowIconsSelectExample from "../../examples/molecules/select/content/row-icons";
import rowIconsSelectSource from "../../examples/molecules/select/content/row-icons?source=file";
import SelectionBlockSelectExample from "../../examples/molecules/select/content/selection";
import selectionBlockSelectSource from "../../examples/molecules/select/content/selection?source=file";
import StatusIconSelectExample from "../../examples/molecules/select/content/status-icon";
import statusIconSelectSource from "../../examples/molecules/select/content/status-icon?source=file";
import TopicGlyphSelectExample from "../../examples/molecules/select/content/topic-glyph";
import topicGlyphSelectSource from "../../examples/molecules/select/content/topic-glyph?source=file";
import WholePickerSelectExample from "../../examples/molecules/select/content/whole-picker";
import wholePickerSelectSource from "../../examples/molecules/select/content/whole-picker?source=file";
import StyleguideExample from "../../styleguide-example";

export default <template>
  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.defaults_example"}}
    @description={{i18n
      "styleguide.sections.select.content.defaults_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.defaults_try_this"}}
    @code={{defaultsSelectSource}}
  >
    <div class="select-examples__control"><DefaultsSelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.glyph_example"}}
    @description={{i18n "styleguide.sections.select.content.glyph_description"}}
    @tryThis={{i18n "styleguide.sections.select.content.glyph_try_this"}}
    @code={{topicGlyphSelectSource}}
  >
    <div class="select-examples__control"><TopicGlyphSelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.row_icon_example"}}
    @description={{i18n
      "styleguide.sections.select.content.row_icon_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.row_icon_try_this"}}
    @code={{rowIconsSelectSource}}
  >
    <div class="select-examples__control"><RowIconsSelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.chip_icon_example"}}
    @description={{i18n
      "styleguide.sections.select.content.chip_icon_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.chip_icon_try_this"}}
    @code={{chipIconsSelectSource}}
  >
    <div class="select-examples__control"><ChipIconsSelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.status_icon_example"}}
    @description={{i18n
      "styleguide.sections.select.content.status_icon_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.status_icon_try_this"}}
    @code={{statusIconSelectSource}}
  >
    <div class="select-examples__control"><StatusIconSelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.computed_example"}}
    @description={{i18n
      "styleguide.sections.select.content.computed_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.computed_try_this"}}
    @code={{computedSelectSource}}
  >
    <div class="select-examples__control"><ComputedSelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.empty_example"}}
    @description={{i18n "styleguide.sections.select.content.empty_description"}}
    @tryThis={{i18n "styleguide.sections.select.content.empty_try_this"}}
    @code={{customEmptySelectSource}}
  >
    <div class="select-examples__control"><CustomEmptySelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.error_example"}}
    @description={{i18n "styleguide.sections.select.content.error_description"}}
    @tryThis={{i18n "styleguide.sections.select.content.error_try_this"}}
    @code={{customErrorSelectSource}}
  >
    <div class="select-examples__control"><CustomErrorSelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.divided_example"}}
    @description={{i18n
      "styleguide.sections.select.content.divided_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.divided_try_this"}}
    @code={{dividerSelectSource}}
  >
    <:default>
      <div class="select-examples__control"><DividerSelectExample /></div>
    </:default>
    <:note>{{i18n "styleguide.sections.select.content.divided_note"}}</:note>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.content.grouped_example"}}
    @description={{i18n
      "styleguide.sections.select.content.grouped_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.grouped_try_this"}}
    @code={{groupedSelectSource}}
  >
    <div class="select-examples__control"><GroupedSelectExample /></div>
  </StyleguideExample>

  <StyleguideExample
    class="--wide"
    @title={{i18n "styleguide.sections.select.content.selection_example"}}
    @description={{i18n
      "styleguide.sections.select.content.selection_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.selection_try_this"}}
    @code={{selectionBlockSelectSource}}
  >
    <div class="select-examples__pair">
      <div class="select-examples__pair-item">
        <p class="select-examples__pair-label">
          {{i18n "styleguide.sections.select.content.selection_single_label"}}
        </p>
        <SelectionBlockSelectExample @identifier="sg-selection" />
      </div>
      <div class="select-examples__pair-item">
        <p class="select-examples__pair-label">
          {{i18n "styleguide.sections.select.content.selection_multi_label"}}
        </p>
        <SelectionBlockSelectExample
          @identifier="sg-content-chips"
          @multiple={{true}}
        />
      </div>
    </div>
  </StyleguideExample>

  <StyleguideExample
    class="--wide"
    @title={{i18n "styleguide.sections.select.content.footer_example"}}
    @description={{i18n
      "styleguide.sections.select.content.footer_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.footer_try_this"}}
    @code={{footerSelectSource}}
  >
    <div class="select-examples__triple">
      <div class="select-examples__pair-item">
        <p class="select-examples__pair-label">
          {{i18n "styleguide.sections.select.content.footer_state_items"}}
        </p>
        <FooterSelectExample @identifier="sg-footer" @state="items" />
      </div>
      <div class="select-examples__pair-item">
        <p class="select-examples__pair-label">
          {{i18n "styleguide.sections.select.content.footer_state_empty"}}
        </p>
        <FooterSelectExample @identifier="sg-footer-empty" @state="empty" />
      </div>
      <div class="select-examples__pair-item">
        <p class="select-examples__pair-label">
          {{i18n "styleguide.sections.select.content.footer_state_error"}}
        </p>
        <FooterSelectExample @identifier="sg-footer-error" @state="error" />
      </div>
    </div>
  </StyleguideExample>

  <StyleguideExample
    class="--wide"
    @title={{i18n "styleguide.sections.select.content.picker_example"}}
    @description={{i18n
      "styleguide.sections.select.content.picker_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.content.picker_try_this"}}
    @code={{wholePickerSelectSource}}
  >
    <div class="select-examples__control"><WholePickerSelectExample /></div>
  </StyleguideExample>
</template>

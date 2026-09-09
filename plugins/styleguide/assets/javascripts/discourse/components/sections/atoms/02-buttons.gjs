import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import DangerSizesExample from "../../examples/atoms/buttons/danger-sizes";
import dangerSizesSource from "../../examples/atoms/buttons/danger-sizes?source=file";
import DangerStatesExample from "../../examples/atoms/buttons/danger-states";
import dangerStatesSource from "../../examples/atoms/buttons/danger-states?source=file";
import FlatSizesExample from "../../examples/atoms/buttons/flat-sizes";
import flatSizesSource from "../../examples/atoms/buttons/flat-sizes?source=file";
import FlatStatesExample from "../../examples/atoms/buttons/flat-states";
import flatStatesSource from "../../examples/atoms/buttons/flat-states?source=file";
import IconSizesExample from "../../examples/atoms/buttons/icon-sizes";
import iconSizesSource from "../../examples/atoms/buttons/icon-sizes?source=file";
import IconStatesExample from "../../examples/atoms/buttons/icon-states";
import iconStatesSource from "../../examples/atoms/buttons/icon-states?source=file";
import IconTextSizesExample from "../../examples/atoms/buttons/icon-text-sizes";
import iconTextSizesSource from "../../examples/atoms/buttons/icon-text-sizes?source=file";
import IconTextStatesExample from "../../examples/atoms/buttons/icon-text-states";
import iconTextStatesSource from "../../examples/atoms/buttons/icon-text-states?source=file";
import LinkExample from "../../examples/atoms/buttons/link";
import linkSource from "../../examples/atoms/buttons/link?source=file";
import PrimarySizesExample from "../../examples/atoms/buttons/primary-sizes";
import primarySizesSource from "../../examples/atoms/buttons/primary-sizes?source=file";
import PrimaryStatesExample from "../../examples/atoms/buttons/primary-states";
import primaryStatesSource from "../../examples/atoms/buttons/primary-states?source=file";
import TextSizesExample from "../../examples/atoms/buttons/text-sizes";
import textSizesSource from "../../examples/atoms/buttons/text-sizes?source=file";
import TextStatesExample from "../../examples/atoms/buttons/text-states";
import textStatesSource from "../../examples/atoms/buttons/text-states?source=file";
import ToggleSwitchExample from "../../examples/atoms/buttons/toggle-switch";
import toggleSwitchSource from "../../examples/atoms/buttons/toggle-switch?source=file";
import TransparentStatesExample from "../../examples/atoms/buttons/transparent-states";
import transparentStatesSource from "../../examples/atoms/buttons/transparent-states?source=file";

export default <template>
  <StyleguideExample
    @code={{iconSizesSource}}
    @title="DButton - icon only - sizes (large, default, small)"
  >
    <IconSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{iconStatesSource}}
    @title="DButton - icon only - states"
  >
    <IconStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{textSizesSource}}
    @title="DButton - text only - sizes (large, default, small)"
  >
    <TextSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{textStatesSource}}
    @title="DButton - text only - states"
  >
    <TextStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{iconTextSizesSource}}
    @title="DButton - icon and text - sizes (large, default, small)"
  >
    <IconTextSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{iconTextStatesSource}}
    @title="DButton - icon and text - states"
  >
    <IconTextStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{primarySizesSource}}
    @title="DButton - icon and text - sizes"
  >
    <PrimarySizesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{primaryStatesSource}}
    @title="DButton - icon and text - btn-primary - states"
  >
    <PrimaryStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{dangerSizesSource}}
    @title="DButton - icon and text - btn-danger - sizes"
  >
    <DangerSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{dangerStatesSource}}
    @title="DButton - icon and text - btn-danger - states"
  >
    <DangerStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{flatSizesSource}}
    @title="DButton - btn-flat - icon only - sizes"
  >
    <FlatSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{flatStatesSource}}
    @title="DButton - btn-flat - states"
  >
    <FlatStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{transparentStatesSource}}
    @title="DButton - btn-transparent - states"
  >
    <TransparentStatesExample />
  </StyleguideExample>

  <StyleguideExample @code={{linkSource}} @title="DButton - link">
    <LinkExample />
  </StyleguideExample>

  <StyleguideExample @code={{toggleSwitchSource}} @title="DToggleSwitch">
    <ToggleSwitchExample />
  </StyleguideExample>
</template>

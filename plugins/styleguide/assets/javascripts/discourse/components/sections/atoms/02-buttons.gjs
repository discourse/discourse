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
    @title="DButton - icon only - sizes (large, default, small)"
    @code={{iconSizesSource}}
  >
    <IconSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - icon only - states"
    @code={{iconStatesSource}}
  >
    <IconStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - text only - sizes (large, default, small)"
    @code={{textSizesSource}}
  >
    <TextSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - text only - states"
    @code={{textStatesSource}}
  >
    <TextStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - icon and text - sizes (large, default, small)"
    @code={{iconTextSizesSource}}
  >
    <IconTextSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - icon and text - states"
    @code={{iconTextStatesSource}}
  >
    <IconTextStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - icon and text - sizes"
    @code={{primarySizesSource}}
  >
    <PrimarySizesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - icon and text - btn-primary - states"
    @code={{primaryStatesSource}}
  >
    <PrimaryStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - icon and text - btn-danger - sizes"
    @code={{dangerSizesSource}}
  >
    <DangerSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - icon and text - btn-danger - states"
    @code={{dangerStatesSource}}
  >
    <DangerStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - btn-flat - icon only - sizes"
    @code={{flatSizesSource}}
  >
    <FlatSizesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - btn-flat - states"
    @code={{flatStatesSource}}
  >
    <FlatStatesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DButton - btn-transparent - states"
    @code={{transparentStatesSource}}
  >
    <TransparentStatesExample />
  </StyleguideExample>

  <StyleguideExample @title="DButton - link" @code={{linkSource}}>
    <LinkExample />
  </StyleguideExample>

  <StyleguideExample @title="DToggleSwitch" @code={{toggleSwitchSource}}>
    <ToggleSwitchExample />
  </StyleguideExample>
</template>

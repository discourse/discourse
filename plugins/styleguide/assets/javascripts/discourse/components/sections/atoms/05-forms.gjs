import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import AlertExample from "../../examples/atoms/forms/alert";
import alertSource from "../../examples/atoms/forms/alert?source=file";
import CheckboxGroupExample from "../../examples/atoms/forms/checkbox-group";
import checkboxGroupSource from "../../examples/atoms/forms/checkbox-group?source=file";
import CodeExample from "../../examples/atoms/forms/code";
import codeSource from "../../examples/atoms/forms/code?source=file";
import CollectionExample from "../../examples/atoms/forms/collection";
import collectionSource from "../../examples/atoms/forms/collection?source=file";
import ColorExample from "../../examples/atoms/forms/color";
import colorSource from "../../examples/atoms/forms/color?source=file";
import ColorNamedExample from "../../examples/atoms/forms/color-named";
import colorNamedSource from "../../examples/atoms/forms/color-named?source=file";
import ColorPrefixHexExample from "../../examples/atoms/forms/color-prefix-hex";
import colorPrefixHexSource from "../../examples/atoms/forms/color-prefix-hex?source=file";
import ColorSwatchesExample from "../../examples/atoms/forms/color-swatches";
import colorSwatchesSource from "../../examples/atoms/forms/color-swatches?source=file";
import ComposerExample from "../../examples/atoms/forms/composer";
import composerSource from "../../examples/atoms/forms/composer?source=file";
import IconExample from "../../examples/atoms/forms/icon";
import iconSource from "../../examples/atoms/forms/icon?source=file";
import ImageExample from "../../examples/atoms/forms/image";
import imageSource from "../../examples/atoms/forms/image?source=file";
import InputExample from "../../examples/atoms/forms/input";
import inputSource from "../../examples/atoms/forms/input?source=file";
import InputGroupExample from "../../examples/atoms/forms/input-group";
import inputGroupSource from "../../examples/atoms/forms/input-group?source=file";
import MenuExample from "../../examples/atoms/forms/menu";
import menuSource from "../../examples/atoms/forms/menu?source=file";
import MultilineExample from "../../examples/atoms/forms/multiline";
import multilineSource from "../../examples/atoms/forms/multiline?source=file";
import QuestionExample from "../../examples/atoms/forms/question";
import questionSource from "../../examples/atoms/forms/question?source=file";
import RadioGroupExample from "../../examples/atoms/forms/radio-group";
import radioGroupSource from "../../examples/atoms/forms/radio-group?source=file";
import RowColExample from "../../examples/atoms/forms/row-col";
import rowColSource from "../../examples/atoms/forms/row-col?source=file";
import SectionExample from "../../examples/atoms/forms/section";
import sectionSource from "../../examples/atoms/forms/section?source=file";
import SelectExample from "../../examples/atoms/forms/select";
import selectSource from "../../examples/atoms/forms/select?source=file";
import TagChooserExample from "../../examples/atoms/forms/tag-chooser";
import tagChooserSource from "../../examples/atoms/forms/tag-chooser?source=file";
import TextareaExample from "../../examples/atoms/forms/textarea";
import textareaSource from "../../examples/atoms/forms/textarea?source=file";
import ToggleExample from "../../examples/atoms/forms/toggle";
import toggleSource from "../../examples/atoms/forms/toggle?source=file";
import ValidationExample from "../../examples/atoms/forms/validation";
import validationSource from "../../examples/atoms/forms/validation?source=file";

export default <template>
  <h2>Controls</h2>

  <StyleguideExample @code={{inputSource}} @title="Input">
    <InputExample />
  </StyleguideExample>

  <StyleguideExample @code={{questionSource}} @title="Question">
    <QuestionExample />
  </StyleguideExample>

  <StyleguideExample @code={{toggleSource}} @title="Toggle">
    <ToggleExample />
  </StyleguideExample>

  <StyleguideExample @code={{composerSource}} @title="Composer">
    <ComposerExample />
  </StyleguideExample>

  <StyleguideExample @code={{codeSource}} @title="Code">
    <CodeExample />
  </StyleguideExample>

  <StyleguideExample @code={{textareaSource}} @title="Textarea">
    <TextareaExample />
  </StyleguideExample>

  <StyleguideExample @code={{selectSource}} @title="Select">
    <SelectExample />
  </StyleguideExample>

  <StyleguideExample @code={{checkboxGroupSource}} @title="CheckboxGroup">
    <CheckboxGroupExample />
  </StyleguideExample>

  <StyleguideExample @code={{imageSource}} @title="Image">
    <ImageExample />
  </StyleguideExample>

  <StyleguideExample @code={{iconSource}} @title="Icon">
    <IconExample />
  </StyleguideExample>

  <StyleguideExample @code={{tagChooserSource}} @title="TagChooser">
    <TagChooserExample />
  </StyleguideExample>

  <StyleguideExample @code={{menuSource}} @title="Menu">
    <MenuExample />
  </StyleguideExample>

  <StyleguideExample @code={{radioGroupSource}} @title="RadioGroup">
    <RadioGroupExample />
  </StyleguideExample>

  <StyleguideExample @code={{colorSource}} @title="Color">
    <ColorExample />
  </StyleguideExample>

  <StyleguideExample @code={{colorSwatchesSource}} @title="Color with swatches">
    <ColorSwatchesExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{colorNamedSource}}
    @title="Color with named colors"
  >
    <ColorNamedExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{colorPrefixHexSource}}
    @title="Color with # prefix in value"
  >
    <ColorPrefixHexExample />
  </StyleguideExample>

  <h2>Layout</h2>

  <StyleguideExample @code={{sectionSource}} @title="Section">
    <SectionExample />
  </StyleguideExample>

  <StyleguideExample @code={{alertSource}} @title="Alert">
    <AlertExample />
  </StyleguideExample>

  <StyleguideExample @code={{inputGroupSource}} @title="InputGroup">
    <InputGroupExample />
  </StyleguideExample>

  <StyleguideExample @code={{collectionSource}} @title="Collection">
    <CollectionExample />
  </StyleguideExample>

  <StyleguideExample @code={{rowColSource}} @title="Row/Col">
    <RowColExample />
  </StyleguideExample>

  <StyleguideExample @code={{multilineSource}} @title="Multiline">
    <MultilineExample />
  </StyleguideExample>

  <h2>Validation</h2>

  <StyleguideExample @code={{validationSource}} @title="Input">
    <ValidationExample />
  </StyleguideExample>
</template>

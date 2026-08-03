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

  <StyleguideExample @title="Input" @code={{inputSource}}>
    <InputExample />
  </StyleguideExample>

  <StyleguideExample @title="Question" @code={{questionSource}}>
    <QuestionExample />
  </StyleguideExample>

  <StyleguideExample @title="Toggle" @code={{toggleSource}}>
    <ToggleExample />
  </StyleguideExample>

  <StyleguideExample @title="Composer" @code={{composerSource}}>
    <ComposerExample />
  </StyleguideExample>

  <StyleguideExample @title="Code" @code={{codeSource}}>
    <CodeExample />
  </StyleguideExample>

  <StyleguideExample @title="Textarea" @code={{textareaSource}}>
    <TextareaExample />
  </StyleguideExample>

  <StyleguideExample @title="Select" @code={{selectSource}}>
    <SelectExample />
  </StyleguideExample>

  <StyleguideExample @title="CheckboxGroup" @code={{checkboxGroupSource}}>
    <CheckboxGroupExample />
  </StyleguideExample>

  <StyleguideExample @title="Image" @code={{imageSource}}>
    <ImageExample />
  </StyleguideExample>

  <StyleguideExample @title="Icon" @code={{iconSource}}>
    <IconExample />
  </StyleguideExample>

  <StyleguideExample @title="TagChooser" @code={{tagChooserSource}}>
    <TagChooserExample />
  </StyleguideExample>

  <StyleguideExample @title="Menu" @code={{menuSource}}>
    <MenuExample />
  </StyleguideExample>

  <StyleguideExample @title="RadioGroup" @code={{radioGroupSource}}>
    <RadioGroupExample />
  </StyleguideExample>

  <StyleguideExample @title="Color" @code={{colorSource}}>
    <ColorExample />
  </StyleguideExample>

  <StyleguideExample @title="Color with swatches" @code={{colorSwatchesSource}}>
    <ColorSwatchesExample />
  </StyleguideExample>

  <StyleguideExample
    @title="Color with named colors"
    @code={{colorNamedSource}}
  >
    <ColorNamedExample />
  </StyleguideExample>

  <StyleguideExample
    @title="Color with # prefix in value"
    @code={{colorPrefixHexSource}}
  >
    <ColorPrefixHexExample />
  </StyleguideExample>

  <h2>Layout</h2>

  <StyleguideExample @title="Section" @code={{sectionSource}}>
    <SectionExample />
  </StyleguideExample>

  <StyleguideExample @title="Alert" @code={{alertSource}}>
    <AlertExample />
  </StyleguideExample>

  <StyleguideExample @title="InputGroup" @code={{inputGroupSource}}>
    <InputGroupExample />
  </StyleguideExample>

  <StyleguideExample @title="Collection" @code={{collectionSource}}>
    <CollectionExample />
  </StyleguideExample>

  <StyleguideExample @title="Row/Col" @code={{rowColSource}}>
    <RowColExample />
  </StyleguideExample>

  <StyleguideExample @title="Multiline" @code={{multilineSource}}>
    <MultilineExample />
  </StyleguideExample>

  <h2>Validation</h2>

  <StyleguideExample @title="Input" @code={{validationSource}}>
    <ValidationExample />
  </StyleguideExample>
</template>

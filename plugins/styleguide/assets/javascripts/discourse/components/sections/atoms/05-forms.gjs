import Component from "@glimmer/component";
import { array, fn, hash } from "@ember/helper";
import Form from "discourse/components/form";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Forms extends Component {
  get inputCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Username" @name="username" as |field|>
      <field.Input placeholder="Username" />
    </form.Field>
    <form.Field @title="Age" @name="age" as |field|>
      <field.Input placeholder="Age" @type="number" @format="small" />
    </form.Field>
    <form.Field @title="Website" @name="website" as |field|>
      <field.Input @before="https://" @after=".com" @format="large" />
    </form.Field>
    <form.Field @title="After" @name="after" as |field|>
      <field.Input @after=".com" />
    </form.Field>
    <form.Field @title="Before" @name="before" as |field|>
      <field.Input @before="https://" />
    </form.Field>
    <form.Field
      @title="Secret"
      @name="secret"
      @description="An important password"
      as |field|
    >
      <field.Password />
    </form.Field>
  </Form>
</template>`;
  }

  get questionCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Enabled" @name="enabled" as |field|>
      <field.Question />
    </form.Field>
  </Form>
</template>`;
  }

  get toggleCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Enabled" @name="enabled" as |field|>
      <field.Toggle />
    </form.Field>
  </Form>
</template>`;
  }

  get composerCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Query" @name="query" as |field|>
      <field.Composer />
    </form.Field>
  </Form>
</template>`;
  }

  get codeCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Query" @name="query" as |field|>
      <field.Code />
    </form.Field>
  </Form>
</template>`;
  }

  get textareaCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Query" @name="query" as |field|>
      <field.Textarea />
    </form.Field>
  </Form>
</template>`;
  }

  get selectCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Enabled" @name="enabled" as |field|>
      <field.Select as |select|>
        <select.Option @value="true">Yes</select.Option>
        <select.Option @value="false">No</select.Option>
      </field.Select>
    </form.Field>
  </Form>
</template>`;
  }

  get checkboxGroupCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.CheckboxGroup
      @title="I give explicit permission"
      as |checkboxGroup|
    >
      <checkboxGroup.Field
        @title="Use my email for any purpose."
        @name="contract"
        as |field|
      >
        <field.Checkbox>Including signing up for services I can't unsubscribe
          to.</field.Checkbox>
      </checkboxGroup.Field>
      <checkboxGroup.Field
        @title="Sign my soul away."
        @name="contract2"
        as |field|
      >
        <field.Checkbox>Will severly impact the afterlife experience.</field.Checkbox>
      </checkboxGroup.Field>
    </form.CheckboxGroup>
  </Form>
</template>`;
  }

  get imageCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Image" @name="image" as |field|>
      <field.Image @type="avatar" />
    </form.Field>
  </Form>
</template>`;
  }

  get iconCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Icon" @name="icon" as |field|>
      <field.Icon />
    </form.Field>
  </Form>
</template>`;
  }

  get menuCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form data|>
    <form.Field @title="Enabled" @name="enabled" as |field|>
      <field.Menu @selection={{data.enabled}} as |menu|>
        <menu.Item @value="true">Yes</menu.Item>
        <menu.Divider />
        <menu.Item @value="false">No</menu.Item>
      </field.Menu>
    </form.Field>
  </Form>
</template>`;
  }

  get radioGroupCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Enabled" @name="enabled" @format="full" as |field|>
      <field.RadioGroup as |radioGroup|>
        <radioGroup.Radio @value="true">Yes</radioGroup.Radio>
        <radioGroup.Radio @value="false" as |radio|>
          <radio.Title>No</radio.Title>
          <radio.Description>
            Choosing no, will make you inelligible for the contest.
          </radio.Description>
        </radioGroup.Radio>
      </field.RadioGroup>
    </form.Field>
  </Form>
</template>`;
  }

  get colorCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Color" @name="color" as |field|>
      <field.Color placeholder="RRGGBB" />
    </form.Field>
  </Form>
</template>`;
  }

  get colorWithSwatchesCode() {
    return `import { array } from "@ember/helper";
import Form from "discourse/components/form";

const COLORS = ["FF0000", "00FF00", "0000FF", "FFFF00", "FF00FF", "00FFFF"];
const USED_COLORS = ["00FF00"];

<template>
  <Form as |form|>
    <form.Field @title="Color" @name="color" as |field|>
      <field.Color
        @colors={{COLORS}}
        @usedColors={{USED_COLORS}}
        placeholder="RRGGBB"
      />
    </form.Field>
  </Form>
</template>`;
  }

  get colorNamedCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Field @title="Color" @name="color" as |field|>
      <field.Color @allowNamedColors={{true}} placeholder="red, FF0000" />
    </form.Field>
  </Form>
</template>`;
  }

  get sectionCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Section @title="Section title">
      Content
    </form.Section>
  </Form>
</template>`;
  }

  get alertCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Alert @icon="pencil">
      You can edit this form.
    </form.Alert>
  </Form>
</template>`;
  }

  get inputGroupCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.InputGroup as |inputGroup|>
      <inputGroup.Field @title="Username" @name="username" as |field|>
        <field.Input />
      </inputGroup.Field>
      <inputGroup.Field @title="Email" @name="email" as |field|>
        <field.Input />
      </inputGroup.Field>
    </form.InputGroup>
  </Form>
</template>`;
  }

  get collectionCode() {
    return `import { array, fn, hash } from "@ember/helper";
import Form from "discourse/components/form";

<template>
  <Form
    @data={{hash foo=(array (hash bar=1 baz=2) (hash bar=3 baz=4))}}
    as |form|
  >
    <form.Button @action={{fn form.addItemToCollection "foo"}} @icon="plus" />

    <form.Collection @name="foo" as |collection index|>
      <form.Row as |row|>
        <row.Col @size={{6}}>
          <collection.Field @title="Bar" @name="bar" as |field|>
            <field.Input />
          </collection.Field>
        </row.Col>

        <row.Col @size={{4}}>
          <collection.Field @title="Baz" @name="baz" as |field|>
            <field.Input />
          </collection.Field>
        </row.Col>

        <row.Col @size={{2}}>
          <form.Button @action={{fn collection.remove index}} @icon="minus" />
        </row.Col>
      </form.Row>
    </form.Collection>

  </Form>
</template>`;
  }

  get rowColCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Row as |row|>
      <row.Col @size={{6}}>
        <form.Field
          @title="Username"
          @name="username"
          @validation="required"
          as |field|
        >
          <field.Input />
        </form.Field>
      </row.Col>
      <row.Col @size={{4}}>
        <form.Field @title="Email" @name="email" as |field|>
          <field.Input />
        </form.Field>
      </row.Col>
      <row.Col @size={{2}}>
        <form.Submit />
      </row.Col>
    </form.Row>
  </Form>
</template>`;
  }

  get multilineCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form as |form|>
    <form.Row as |row|>
      <row.Col @size={{6}}>
        <form.Field
          @title="Username"
          @name="username"
          @validation="required"
          as |field|
        >
          <field.Input />
        </form.Field>
      </row.Col>
      <row.Col @size={{6}}>
        <form.Field @title="Email" @name="email" as |field|>
          <field.Input />
        </form.Field>
      </row.Col>

      <row.Col @size={{12}}>
        <form.Field @title="Adress" @name="adress" as |field|>
          <field.Input />
        </form.Field>
      </row.Col>
    </form.Row>
  </Form>
</template>`;
  }

  get validationCode() {
    return `import Form from "discourse/components/form";

<template>
  <Form @validateOn="change" as |form|>
    <form.Field
      @title="Username"
      @name="username"
      @validation="required"
      as |field|
    >
      <field.Input />
    </form.Field>

    <form.Field
      @name="accept_terms"
      @title="Accept terms"
      @validation="required"
      @format="large"
      as |field|
    >
      <field.Checkbox />
    </form.Field>

    <form.Submit />
  </Form>
</template>`;
  }

  <template>
    <h2>Controls</h2>
    <StyleguideExample @title="Input" @code={{this.inputCode}}>
      <Form as |form|>
        <form.Field @title="Username" @name="username" as |field|>
          <field.Input placeholder="Username" />
        </form.Field>
        <form.Field @title="Age" @name="age" as |field|>
          <field.Input placeholder="Age" @type="number" @format="small" />
        </form.Field>
        <form.Field @title="Website" @name="website" as |field|>
          <field.Input @before="https://" @after=".com" @format="large" />
        </form.Field>
        <form.Field @title="After" @name="after" as |field|>
          <field.Input @after=".com" />
        </form.Field>
        <form.Field @title="Before" @name="before" as |field|>
          <field.Input @before="https://" />
        </form.Field>
        <form.Field
          @title="Secret"
          @name="secret"
          @description="An important password"
          as |field|
        >
          <field.Password />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Question" @code={{this.questionCode}}>
      <Form as |form|>
        <form.Field @title="Enabled" @name="enabled" as |field|>
          <field.Question />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Toggle" @code={{this.toggleCode}}>
      <Form as |form|>
        <form.Field @title="Enabled" @name="enabled" as |field|>
          <field.Toggle />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Composer" @code={{this.composerCode}}>
      <Form as |form|>
        <form.Field @title="Query" @name="query" as |field|>
          <field.Composer />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Code" @code={{this.codeCode}}>
      <Form as |form|>
        <form.Field @title="Query" @name="query" as |field|>
          <field.Code />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Textarea" @code={{this.textareaCode}}>
      <Form as |form|>
        <form.Field @title="Query" @name="query" as |field|>
          <field.Textarea />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Select" @code={{this.selectCode}}>
      <Form as |form|>
        <form.Field @title="Enabled" @name="enabled" as |field|>
          <field.Select as |select|>
            <select.Option @value="true">Yes</select.Option>
            <select.Option @value="false">No</select.Option>
          </field.Select>
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="CheckboxGroup" @code={{this.checkboxGroupCode}}>
      <Form as |form|>
        <form.CheckboxGroup
          @title="I give explicit permission"
          as |checkboxGroup|
        >
          <checkboxGroup.Field
            @title="Use my email for any purpose."
            @name="contract"
            as |field|
          >
            <field.Checkbox>Including signing up for services I can't
              unsubscribe to.</field.Checkbox>
          </checkboxGroup.Field>
          <checkboxGroup.Field
            @title="Sign my soul away."
            @name="contract2"
            as |field|
          >
            <field.Checkbox>Will severly impact the afterlife experience.</field.Checkbox>
          </checkboxGroup.Field>
        </form.CheckboxGroup>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Image" @code={{this.imageCode}}>
      <Form as |form|>
        <form.Field @title="Image" @name="image" as |field|>
          <field.Image @type="avatar" />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Icon" @code={{this.iconCode}}>
      <Form as |form|>
        <form.Field @title="Icon" @name="icon" as |field|>
          <field.Icon />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Menu" @code={{this.menuCode}}>
      <Form as |form data|>
        <form.Field @title="Enabled" @name="enabled" as |field|>
          <field.Menu @selection={{data.enabled}} as |menu|>
            <menu.Item @value="true">Yes</menu.Item>
            <menu.Divider />
            <menu.Item @value="false">No</menu.Item>
          </field.Menu>
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="RadioGroup" @code={{this.radioGroupCode}}>
      <Form as |form|>
        <form.Field @title="Enabled" @name="enabled" @format="full" as |field|>
          <field.RadioGroup as |radioGroup|>
            <radioGroup.Radio @value="true">Yes</radioGroup.Radio>
            <radioGroup.Radio @value="false" as |radio|>
              <radio.Title>No</radio.Title>
              <radio.Description>
                Choosing no, will make you inelligible for the contest.
              </radio.Description>
            </radioGroup.Radio>
          </field.RadioGroup>
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Color" @code={{this.colorCode}}>
      <Form as |form|>
        <form.Field @title="Color" @name="color" as |field|>
          <field.Color placeholder="RRGGBB" />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample
      @title="Color with swatches"
      @code={{this.colorWithSwatchesCode}}
    >
      <Form as |form|>
        <form.Field @title="Color" @name="color" as |field|>
          <field.Color
            @colors={{array
              "FF0000"
              "00FF00"
              "0000FF"
              "FFFF00"
              "FF00FF"
              "00FFFF"
            }}
            @usedColors={{array "00FF00"}}
            placeholder="RRGGBB"
          />
        </form.Field>
      </Form>
    </StyleguideExample>

    <StyleguideExample
      @title="Color with named colors"
      @code={{this.colorNamedCode}}
    >
      <Form as |form|>
        <form.Field @title="Color" @name="color" as |field|>
          <field.Color @allowNamedColors={{true}} placeholder="red, FF0000" />
        </form.Field>
      </Form>
    </StyleguideExample>

    <h2>Layout</h2>

    <StyleguideExample @title="Section" @code={{this.sectionCode}}>
      <Form as |form|>
        <form.Section @title="Section title">
          Content
        </form.Section>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Alert" @code={{this.alertCode}}>
      <Form as |form|>
        <form.Alert @icon="pencil">
          You can edit this form.
        </form.Alert>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="InputGroup" @code={{this.inputGroupCode}}>
      <Form as |form|>
        <form.InputGroup as |inputGroup|>
          <inputGroup.Field @title="Username" @name="username" as |field|>
            <field.Input />
          </inputGroup.Field>
          <inputGroup.Field @title="Email" @name="email" as |field|>
            <field.Input />
          </inputGroup.Field>
        </form.InputGroup>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Collection" @code={{this.collectionCode}}>
      <Form
        @data={{hash foo=(array (hash bar=1 baz=2) (hash bar=3 baz=4))}}
        as |form|
      >
        <form.Button
          @action={{fn form.addItemToCollection "foo"}}
          @icon="plus"
        />

        <form.Collection @name="foo" as |collection index|>
          <form.Row as |row|>
            <row.Col @size={{6}}>
              <collection.Field @title="Bar" @name="bar" as |field|>
                <field.Input />
              </collection.Field>
            </row.Col>

            <row.Col @size={{4}}>
              <collection.Field @title="Baz" @name="baz" as |field|>
                <field.Input />
              </collection.Field>
            </row.Col>

            <row.Col @size={{2}}>
              <form.Button
                @action={{fn collection.remove index}}
                @icon="minus"
              />
            </row.Col>
          </form.Row>
        </form.Collection>

      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Row/Col" @code={{this.rowColCode}}>
      <Form as |form|>
        <form.Row as |row|>
          <row.Col @size={{6}}>
            <form.Field
              @title="Username"
              @name="username"
              @validation="required"
              as |field|
            >
              <field.Input />
            </form.Field>
          </row.Col>
          <row.Col @size={{4}}>
            <form.Field @title="Email" @name="email" as |field|>
              <field.Input />
            </form.Field>
          </row.Col>
          <row.Col @size={{2}}>
            <form.Submit />
          </row.Col>
        </form.Row>
      </Form>
    </StyleguideExample>

    <StyleguideExample @title="Multiline" @code={{this.multilineCode}}>
      <Form as |form|>
        <form.Row as |row|>
          <row.Col @size={{6}}>
            <form.Field
              @title="Username"
              @name="username"
              @validation="required"
              as |field|
            >
              <field.Input />
            </form.Field>
          </row.Col>
          <row.Col @size={{6}}>
            <form.Field @title="Email" @name="email" as |field|>
              <field.Input />
            </form.Field>
          </row.Col>

          <row.Col @size={{12}}>
            <form.Field @title="Adress" @name="adress" as |field|>
              <field.Input />
            </form.Field>
          </row.Col>
        </form.Row>
      </Form>
    </StyleguideExample>

    <h2>Validation</h2>

    <StyleguideExample @title="Input" @code={{this.validationCode}}>
      <Form @validateOn="change" as |form|>
        <form.Field
          @title="Username"
          @name="username"
          @validation="required"
          as |field|
        >
          <field.Input />
        </form.Field>

        <form.Field
          @name="accept_terms"
          @title="Accept terms"
          @validation="required"
          @format="large"
          as |field|
        >
          <field.Checkbox />
        </form.Field>

        <form.Submit />
      </Form>
    </StyleguideExample>
  </template>
}

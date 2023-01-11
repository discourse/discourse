import { hbs } from "ember-cli-htmlbars";
import { action } from "@storybook/addon-actions";
import { linkTo } from "@storybook/addon-links";

// More on default export: https://storybook.js.org/docs/ember/writing-stories/introduction#default-export
export default {
  title: "Button",
  // More on argTypes: https://storybook.js.org/docs/ember/api/argtypes
  argTypes: {
    children: { control: "text" },
  },
};

// More on component templates: https://storybook.js.org/docs/ember/writing-stories/introduction#using-args
const Template = (args) => ({
  template: hbs`<button {{action onClick}}>{{children}}</button>`,
  context: args,
});

export const Text = Template.bind({});
// More on args: https://storybook.js.org/docs/ember/writing-stories/args
Text.args = {
  children: "Button",
  onClick: action("onClick"),
};

export const Emoji = Template.bind({});
Emoji.args = {
  children: "😀 😎 👍 💯",
};

export const TextWithAction = () => ({
  template: hbs`
    <button {{action onClick}}>
      Trigger Action
    </button>
  `,
  context: {
    onClick: () => action("This was clicked")(),
  },
});

TextWithAction.storyName = "With an action";
TextWithAction.parameters = { notes: "My notes on a button with emojis" };

export const ButtonWithLinkToAnotherStory = () => ({
  template: hbs`
    <button {{action onClick}}>
      Go to Welcome Story
    </button>
  `,
  context: {
    onClick: linkTo("example-introduction--page"),
  },
});

ButtonWithLinkToAnotherStory.storyName = "button with link to another story";

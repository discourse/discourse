import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

const OPTIONS = [
  { id: "1ddc47be0d2315b9711ee8526ca9d83f", html: "This", votes: 0, rank: 0 },
  { id: "70e743697dac09483d7b824eaadb91e1", html: "That", votes: 0, rank: 0 },
  { id: "6c986ebcde3d5822a6e91a695c388094", html: "Other", votes: 0, rank: 0 },
];

const IMAGE_OPTIONS = [
  {
    id: "1ddc47be0d2315b9711ee8526ca9d83f",
    html: "<img src='upload://tpbXHFLPCTLWjyGvtyekmXQN49A.jpeg'></img>",
    votes: 0,
    rank: 0,
  },
  {
    id: "70e743697dac09483d7b824eaadb91e1",
    html: "<img src='upload://eurierXHFETLWjHsdfLKKJDFLKJ.jpeg'></img>",
    votes: 0,
    rank: 0,
  },
];

module("Poll | Component | poll-options", function (hooks) {
  setupRenderingTest(hooks);

  test("single, not selected", async function (assert) {
    this.setProperties({
      isCheckbox: false,
      isRankedChoice: false,
      rankedChoiceDropdownContent: [],
      options: OPTIONS,
      votes: [],
    });

    await render(hbs`<PollOptions
      @isCheckbox={{this.isCheckbox}}
      @isRankedChoice={{this.isRankedChoice}}
      @ranked_choice_dropdown_content={{this.ranked_choice_dropdown_content}}
      @options={{this.options}}
      @votes={{this.votes}}
      @sendRadioClick={{this.toggleOption}}
    />`);

    assert.dom("li .d-icon-far-circle:nth-of-type(1)").exists({ count: 3 });
  });

  test("single, selected", async function (assert) {
    this.setProperties({
      isCheckbox: false,
      isRankedChoice: false,
      rankedChoiceDropdownContent: [],
      options: OPTIONS,
      votes: ["6c986ebcde3d5822a6e91a695c388094"],
    });

    await render(hbs`<PollOptions
        @isCheckbox={{this.isCheckbox}}
        @isRankedChoice={{this.isRankedChoice}}
        @ranked_choice_dropdown_content={{this.ranked_choice_dropdown_content}}
        @options={{this.options}}
        @votes={{this.votes}}
        @sendRadioClick={{this.toggleOption}}
      />`);

    assert.dom("li .d-icon-circle:nth-of-type(1)").exists({ count: 1 });
  });

  test("multi, not selected", async function (assert) {
    this.setProperties({
      isCheckbox: true,
      isRankedChoice: false,
      rankedChoiceDropdownContent: [],
      options: OPTIONS,
      votes: [],
    });

    await render(hbs`<PollOptions
        @isCheckbox={{this.isCheckbox}}
        @isRankedChoice={{this.isRankedChoice}}
        @ranked_choice_dropdown_content={{this.ranked_choice_dropdown_content}}
        @options={{this.options}}
        @votes={{this.votes}}
        @sendRadioClick={{this.toggleOption}}
      />`);

    assert.dom("li .d-icon-far-square:nth-of-type(1)").exists({ count: 3 });
  });

  test("multi, selected", async function (assert) {
    this.setProperties({
      isCheckbox: true,
      isRankedChoice: false,
      rankedChoiceDropdownContent: [],
      options: OPTIONS,
      votes: ["6c986ebcde3d5822a6e91a695c388094"],
    });

    await render(hbs`<PollOptions
      @isCheckbox={{this.isCheckbox}}
      @isRankedChoice={{this.isRankedChoice}}
      @ranked_choice_dropdown_content={{this.ranked_choice_dropdown_content}}
      @options={{this.options}}
      @votes={{this.votes}}
      @sendRadioClick={{this.toggleOption}}
    />`);

    assert
      .dom("li .d-icon-far-square-check:nth-of-type(1)")
      .exists({ count: 1 });
  });

  test("single with images", async function (assert) {
    this.setProperties({
      isCheckbox: false,
      options: IMAGE_OPTIONS,
      votes: [],
    });

    await render(hbs`<PollOptions
      @isCheckbox={{this.isCheckbox}}
      @options={{this.options}}
      @votes={{this.votes}}
      @sendRadioClick={{this.toggleOption}}
    />`);

    assert.dom("li img").exists({ count: 2 });
  });

  test("ranked choice - priorities", async function (assert) {
    this.setProperties({
      isCheckbox: false,
      isRankedChoice: true,
      rankedChoiceDropdownContent: [],
      options: OPTIONS,
      votes: [],
    });

    await render(hbs`<PollOptions
      @isCheckbox={{this.isCheckbox}}
      @isRankedChoice={{this.isRankedChoice}}
      @ranked_choice_dropdown_content={{this.ranked_choice_dropdown_content}}
      @options={{this.options}}
      @votes={{this.votes}}
      @sendRadioClick={{this.toggleOption}}
    />`);

    await click(
      `.ranked-choice-poll-option[data-poll-option-id='${OPTIONS[0].id}'] button`
    );

    assert
      .dom(".dropdown-menu__item:nth-child(2)")
      .hasText(`1 ${I18n.t("poll.options.ranked_choice.highest_priority")}`);

    assert
      .dom(".dropdown-menu__item:nth-child(4)")
      .hasText(`3 ${I18n.t("poll.options.ranked_choice.lowest_priority")}`);
  });
});

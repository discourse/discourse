import { render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DsaModerationDetails from "discourse/components/dsa-moderation-details";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";

const RESPECT = {
  id: "rule-respect",
  ground: "Be respectful",
  explanation: "Personal attacks are not allowed.",
};
const ADVERTISING = {
  id: "rule-advertising",
  ground: "No advertising",
  explanation: "Unsolicited advertising is not allowed.",
};

const OTHER_VIOLATION = {
  id: "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
  name: "Other violation of terms and conditions",
};
const SCAMS = {
  id: "STATEMENT_CATEGORY_SCAMS_AND_FRAUD",
  name: "Scams and fraud",
};
const CATEGORY = ".dsa-moderation-details [data-name='category']";

function categoryOptions({ defaultCategory } = {}) {
  return {
    community_rules: [RESPECT, ADVERTISING],
    categories: [OTHER_VIOLATION, SCAMS],
    default_category: defaultCategory,
  };
}

function classificationOptions(communityRules) {
  return {
    community_rules: communityRules,
    categories: [
      {
        id: "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
        name: "Other violation of terms and conditions",
      },
    ],
    default_category: "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
  };
}

module("Integration | Component | DsaModerationDetails", function (hooks) {
  setupRenderingTest(hooks);

  module("with the new select controls", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("offers each community rule with its explanation", async function (assert) {
      const options = classificationOptions([RESPECT, ADVERTISING]);

      await render(
        <template><DsaModerationDetails @options={{options}} /></template>
      );

      const rule = ".dsa-moderation-details [data-name='community_rule']";
      assert
        .dom(`${rule} [role='combobox']`)
        .hasAria("label", i18n("dsa_statements.rule"))
        .hasAttribute("placeholder", i18n("dsa_statements.rule_prompt"));

      await dSelect(`${rule} .d-select`).open();

      assert.deepEqual(
        [...document.querySelectorAll("[role='option']")].map((option) => [
          option.dataset.value,
          option.dataset.name,
          option
            .querySelector(".d-select__option-description")
            ?.textContent.trim(),
        ]),
        [
          [RESPECT.id, RESPECT.ground, RESPECT.explanation],
          [ADVERTISING.id, ADVERTISING.ground, ADVERTISING.explanation],
        ]
      );
    });

    test("narrows the rules as a moderator types", async function (assert) {
      const options = classificationOptions([RESPECT, ADVERTISING]);

      await render(
        <template><DsaModerationDetails @options={{options}} /></template>
      );
      await dSelect(
        ".dsa-moderation-details [data-name='community_rule'] .d-select"
      ).search("advert");

      assert.deepEqual(
        [...document.querySelectorAll("[role='option']")].map(
          (option) => option.dataset.value
        ),
        [ADVERTISING.id]
      );
    });

    test("submits the picked rule", async function (assert) {
      const options = classificationOptions([RESPECT, ADVERTISING]);
      let submitted;
      const onSubmit = (data) => (submitted = data);

      await render(
        <template>
          <DsaModerationDetails @onSubmit={{onSubmit}} @options={{options}} />
        </template>
      );
      await dSelect(
        ".dsa-moderation-details [data-name='community_rule'] .d-select"
      ).select(ADVERTISING.id);
      await formKit().submit();

      assert.strictEqual(submitted.community_rule, ADVERTISING.id);
    });

    test("holds a site's only rule from the start", async function (assert) {
      const options = classificationOptions([RESPECT]);

      await render(
        <template><DsaModerationDetails @options={{options}} /></template>
      );

      assert
        .dom(
          ".dsa-moderation-details [data-name='community_rule'] [role='combobox']"
        )
        .hasValue(RESPECT.ground);
    });

    test("is disabled with the form", async function (assert) {
      const options = classificationOptions([RESPECT, ADVERTISING]);

      await render(
        <template>
          <DsaModerationDetails @disabled={{true}} @options={{options}} />
        </template>
      );

      assert
        .dom(
          ".dsa-moderation-details [data-name='community_rule'] [role='combobox']"
        )
        .isDisabled();
    });

    module("the category field", function () {
      test("offers each category in a typeahead named for the field", async function (assert) {
        const options = categoryOptions();

        await render(
          <template><DsaModerationDetails @options={{options}} /></template>
        );

        assert
          .dom(`${CATEGORY} [role='combobox']`)
          .hasAria("label", i18n("dsa_statements.category"))
          .hasAttribute("placeholder", i18n("dsa_statements.category_prompt"));

        await dSelect(`${CATEGORY} .d-select`).open();

        assert.deepEqual(
          [...document.querySelectorAll("[role='option']")].map((option) => [
            option.dataset.value,
            option.dataset.name,
          ]),
          [
            [OTHER_VIOLATION.id, OTHER_VIOLATION.name],
            [SCAMS.id, SCAMS.name],
          ]
        );
      });

      test("narrows the categories as a moderator types", async function (assert) {
        const options = categoryOptions();

        await render(
          <template><DsaModerationDetails @options={{options}} /></template>
        );
        await dSelect(`${CATEGORY} .d-select`).search("scam");

        assert.deepEqual(
          [...document.querySelectorAll("[role='option']")].map(
            (option) => option.dataset.value
          ),
          [SCAMS.id]
        );
      });

      test("submits the picked category", async function (assert) {
        const options = categoryOptions();
        let submitted;
        const onSubmit = (data) => (submitted = data);

        await render(
          <template>
            <DsaModerationDetails @onSubmit={{onSubmit}} @options={{options}} />
          </template>
        );
        await dSelect(
          ".dsa-moderation-details [data-name='community_rule'] .d-select"
        ).select(RESPECT.id);
        await dSelect(`${CATEGORY} .d-select`).select(SCAMS.id);
        await formKit().submit();

        assert.strictEqual(submitted.category, SCAMS.id);
      });

      test("holds the site's default category from the start, named by its value alone", async function (assert) {
        const options = categoryOptions({ defaultCategory: SCAMS.id });

        await render(
          <template><DsaModerationDetails @options={{options}} /></template>
        );

        assert.dom(`${CATEGORY} [role='combobox']`).hasValue(SCAMS.name);
        assert
          .dom(`${CATEGORY} .dsa-classification-selected-label`)
          .doesNotExist("the field's label doesn't repeat the held category");
      });

      test("links the category definitions from the panel, where Tab reaches the link", async function (assert) {
        const options = categoryOptions();

        await render(
          <template><DsaModerationDetails @options={{options}} /></template>
        );
        await dSelect(`${CATEGORY} .d-select`).open();

        const link = ".d-select__footer a";
        assert
          .dom(link)
          .hasText(i18n("dsa_statements.category_definitions"))
          .hasAttribute(
            "href",
            "https://transparency.dsa.ec.europa.eu/page/documentation#16.-category-%26-specification"
          )
          .hasAttribute("target", "_blank")
          .hasAttribute("rel", "noopener noreferrer");

        await triggerKeyEvent(
          `${CATEGORY} [role='combobox']`,
          "keydown",
          "Tab"
        );

        assert.dom(link).isFocused();
      });

      test("is disabled with the form", async function (assert) {
        const options = categoryOptions();

        await render(
          <template>
            <DsaModerationDetails @disabled={{true}} @options={{options}} />
          </template>
        );

        assert.dom(`${CATEGORY} [role='combobox']`).isDisabled();
      });
    });
  });
});

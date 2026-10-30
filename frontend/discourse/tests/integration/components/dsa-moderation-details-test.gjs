import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DsaModerationDetails from "discourse/components/dsa-moderation-details";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { NO_VALUE_OPTION } from "discourse/ui-kit/d-native-select";

const CATEGORY = { id: "STATEMENT_CATEGORY_SCAMS_AND_FRAUD", name: "Scams" };
const RULE = { id: "first", ground: "Be respectful" };
const OTHER_RULE = { id: "second", ground: "No spam" };

module("Integration | Component | DsaModerationDetails", function (hooks) {
  setupRenderingTest(hooks);

  test("selects the community rule when there is only one", async function (assert) {
    const options = { community_rules: [RULE], categories: [CATEGORY] };
    let submitted;
    const onSubmit = (data) => (submitted = data);

    await render(
      <template>
        <DsaModerationDetails @onSubmit={{onSubmit}} @options={{options}} />
      </template>
    );

    assert.form().field("community_rule").hasValue(RULE.id);

    await formKit().field("category").select(CATEGORY.id);
    await formKit().submit();

    assert.strictEqual(submitted.community_rule, RULE.id);
    assert.strictEqual(submitted.category, CATEGORY.id);
  });

  test("leaves the community rule empty when there are several", async function (assert) {
    const options = {
      community_rules: [RULE, OTHER_RULE],
      categories: [CATEGORY],
    };

    await render(
      <template><DsaModerationDetails @options={{options}} /></template>
    );

    assert.form().field("community_rule").hasValue(NO_VALUE_OPTION);
  });
});

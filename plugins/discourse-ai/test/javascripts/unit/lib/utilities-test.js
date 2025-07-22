/* eslint-disable qunit/no-assert-equal */
/* eslint-disable qunit/no-loose-assertions */
import { module, test } from "qunit";
import { jsonToHtml } from "discourse/plugins/discourse-ai/discourse/lib/utilities";

module("Unit | Utility | json-to-html", function () {
  test("it properly handles nulls", function (assert) {
    const input = null;
    const result = jsonToHtml(input).toString();

    assert.equal(result, "null", "Null should be properly formatted");
  });

  test("it properly handles boolean", function (assert) {
    const input = true;
    const result = jsonToHtml(input).toString();

    assert.equal(result, "true", "Boolean should be properly formatted");
  });

  test("it properly handles numbers", function (assert) {
    const input = 42.1;
    const result = jsonToHtml(input).toString();

    assert.equal(result, "42.1", "Numbers should be properly formatted");
  });

  test("it properly handles undefined", function (assert) {
    const input = undefined;
    const result = jsonToHtml(input).toString();

    assert.equal(result, "", "Undefined should be properly formatted");
  });

  test("it handles nested objects correctly", function (assert) {
    const input = {
      outer: {
        inner: {
          key: "value",
        },
      },
    };

    const result = jsonToHtml(input).toString();
    const expected =
      "<ul><li><strong>outer:</strong> <ul><li><ul><li><strong>inner:</strong> <ul><li><ul><li><strong>key:</strong> value</li></ul></li></ul></li></ul></li></ul></li></ul>";

    assert.equal(
      result,
      expected,
      "Nested objects should be properly formatted"
    );
  });

  test("it handles arrays correctly", function (assert) {
    const input = {
      array: [1, 2, 3],
    };

    const result = jsonToHtml(input).toString();

    const expected =
      "<ul><li><strong>array:</strong> <ul><li><strong>0:</strong> 1</li><li><strong>1:</strong> 2</li><li><strong>2:</strong> 3</li></ul></li></ul>";

    assert.equal(result, expected, "Arrays should be properly formatted");
  });
});

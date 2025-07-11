import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ParamInputForm, {
  ERRORS,
} from "discourse/plugins/discourse-data-explorer/discourse/components/param-input-form";

const InputTestCases = [
  {
    type: "string",
    default: "foo",
    initial: "bar",
    tests: [
      { input: "", data_null: "", error: ERRORS.REQUIRED },
      { input: " ", data_null: " ", error: ERRORS.REQUIRED },
      { input: "str", data: "str" },
    ],
  },
  {
    type: "int",
    default: "123",
    initial: "456",
    tests: [
      { input: "", data_null: "", error: ERRORS.REQUIRED },
      { input: "1234", data: "1234" },
      { input: "0", data: "0" },
      { input: "-2147483648", data: "-2147483648" },
      { input: "2147483649", error: ERRORS.OVERFLOW_HIGH },
      { input: "-2147483649", error: ERRORS.OVERFLOW_LOW },
    ],
  },
  {
    type: "bigint",
    default: "123",
    initial: "456",
    tests: [
      { input: "", data_null: undefined, error: ERRORS.REQUIRED },
      { input: "123", data: "123" },
      { input: "0", data: "0" },
      { input: "-2147483649", data: "-2147483649" },
      { input: "2147483649", data: "2147483649" },
      { input: "abcd", error: ERRORS.NOT_A_NUMBER },
      { input: "114.514", error: ERRORS.NOT_AN_INTEGER },
    ],
  },
  {
    type: "category_id",
    default: "4",
    initial: "3",
    tests: [
      {
        input: null,
        data_null: "",
        error: ERRORS.REQUIRED,
      },
      {
        input: async () => {
          const categoryChooser = selectKit(".category-chooser");

          await categoryChooser.expand();
          await categoryChooser.selectRowByValue(2);
        },
        data: "2",
      },
    ],
  },
  {
    type: "group_id",
    default: "trust_level_1",
    initial: "trust_level_3",
    tests: [
      {
        input: null,
        data_null: undefined,
        error: ERRORS.REQUIRED,
      },
      {
        input: async () => {
          const groupChooser = selectKit(".group-chooser");
          await groupChooser.expand();
          await groupChooser.selectRowByValue("trust_level_2");
        },
        data: "trust_level_2",
      },
    ],
  },
  {
    type: "group_list",
    default: "trust_level_1",
    initial: "trust_level_3,trust_level_4",
    tests: [
      {
        input: null,
        data_null: "",
        error: ERRORS.REQUIRED,
      },
    ],
  },
  {
    type: "date",
    default: "2024-07-13",
    initial: "1970-01-01",
    tests: [
      {
        input: null,
        data_null: undefined,
        error: ERRORS.REQUIRED,
      },
      {
        input: "2038-01-20",
        data: "2038-01-20",
      },
    ],
  },
  {
    type: "time",
    default: "12:34",
    initial: "11:45",
    tests: [
      {
        input: null,
        data_null: undefined,
        error: ERRORS.REQUIRED,
      },
      {
        input: "03:14",
        data: "03:14",
      },
    ],
  },
  {
    type: "datetime",
    default: "2024-07-13 12:00",
    initial: "1970-01-01 00:00",
    tests: [
      {
        input: null,
        data_null: undefined,
        error: ERRORS.REQUIRED,
      },
      {
        input: "2038-01-19 03:15",
        data: "2038-01-19 03:15",
      },
    ],
  },
];

module("Data Explorer Plugin | Component | param-input", function (hooks) {
  setupRenderingTest(hooks);

  for (const testcase of InputTestCases) {
    for (const config of [
      { default: testcase.default },
      { nullable: false, initial: testcase.initial },
      { nullable: false, default: testcase.default, initial: testcase.initial },
      { nullable: true },
    ]) {
      const testName = ["type"];
      if (config.nullable) {
        testName.push("nullable");
      }
      testName.push(testcase.type);
      if (config.initial) {
        testName.push("with initial value");
      }
      if (config.initial) {
        testName.push("with default");
      }

      test(testName.join(" "), async function (assert) {
        const self = this;

        this.setProperties({
          param_info: [
            {
              identifier: testcase.type,
              type: testcase.type,
              default: config.default ?? null,
              nullable: config.nullable,
            },
          ],
          initialValues: config.initial
            ? { [testcase.type]: config.initial }
            : {},
          onRegisterApi: ({ submit, allNormalized }) => {
            this.submit = submit;
            this.allNormalized = allNormalized;
          },
        });

        await render(
          <template>
            <ParamInputForm
              @hasParams="true"
              @initialValues={{self.initialValues}}
              @paramInfo={{self.param_info}}
              @onRegisterApi={{self.onRegisterApi}}
            />
          </template>
        );

        await this.allNormalized;

        if (config.initial || config.default) {
          const data = await this.submit();
          const val = config.initial || config.default;
          assert.strictEqual(
            data[testcase.type],
            val,
            `has initial/default value "${val}"`
          );
        }

        for (const t of testcase.tests) {
          if (t.input == null && (config.initial || config.default)) {
            continue;
          }
          await formKit().reset();
          if (t.input != null) {
            if (typeof t.input === "function") {
              await t.input();
            } else {
              await fillIn(`[name="${testcase.type}"]`, t.input);
            }
          }

          if (config.nullable && "data_null" in t) {
            const data = await this.submit();
            assert.strictEqual(
              data[testcase.type],
              t.data_null,
              `should have null data`
            );
          } else if (t.error) {
            await formKit().submit();
            assert.form().field(testcase.type).hasError(t.error);
          } else {
            const data = await this.submit();
            assert.strictEqual(
              data[testcase.type],
              t.data,
              `data should be "${t.data}"`
            );
          }
        }
      });
    }
  }

  test("empty form will reject submit", async function (assert) {
    const self = this;

    this.setProperties({
      param_info: [
        {
          identifier: "string",
          type: "string",
          default: null,
          nullable: false,
        },
      ],
      initialValues: {},
      onRegisterApi: ({ submit }) => {
        this.submit = submit;
      },
    });

    await render(
      <template>
        <ParamInputForm
          @initialValues={{self.initialValues}}
          @paramInfo={{self.param_info}}
          @onRegisterApi={{self.onRegisterApi}}
        />
      </template>
    );

    assert.rejects(this.submit());

    // After successfully submitting the test once, edit and submit again.
    await fillIn(`[name="string"]`, "foo");
    await this.submit();
    await fillIn(`[name="string"]`, "");
    assert.rejects(this.submit());
  });

  test("async normalization", async function (assert) {
    const self = this;

    this.setProperties({
      param_info: [
        {
          identifier: "category_id",
          type: "category_id",
          default: "support",
          nullable: false,
        },
      ],
      initialValues: {},
      onRegisterApi: (paramInputApi) => {
        this.paramInputApi = paramInputApi;
      },
    });

    await render(
      <template>
        <ParamInputForm
          @initialValues={{self.initialValues}}
          @paramInfo={{self.param_info}}
          @onRegisterApi={{self.onRegisterApi}}
        />
      </template>
    );

    await this.paramInputApi.allNormalized;

    this.paramInputApi.submit().then((res) => {
      assert.strictEqual(res.category_id, "1003");
    });
  });

  test("show error message when default value is invalid", async function (assert) {
    const self = this;

    this.setProperties({
      param_info: [
        {
          identifier: "group_id",
          type: "group_id",
          default: "invalid_group_name",
          nullable: false,
        },
      ],
      initialValues: {},
      onRegisterApi: () => {},
    });

    await render(
      <template>
        <ParamInputForm
          @initialValues={{self.initialValues}}
          @paramInfo={{self.param_info}}
          @onRegisterApi={{self.onRegisterApi}}
        />
      </template>
    );

    assert
      .form()
      .field("group_id")
      .hasError(`${ERRORS.NO_SUCH_GROUP}: invalid_group_name`);
  });

  test("date, time, datetime with initial value in other formats", async function (assert) {
    const self = this;

    this.setProperties({
      param_info: [
        {
          identifier: "date",
          type: "date",
          default: null,
          nullable: false,
        },
        {
          identifier: "time",
          type: "time",
          default: null,
          nullable: false,
        },
        {
          identifier: "datetime",
          type: "datetime",
          default: null,
          nullable: false,
        },
      ],
      initialValues: {
        date: "19 January 2038",
        time: "3:15 am",
        datetime: "19 January 2038 3:15 am",
      },
      onRegisterApi: ({ submit }) => {
        this.submit = submit;
      },
    });

    await render(
      <template>
        <ParamInputForm
          @initialValues={{self.initialValues}}
          @paramInfo={{self.param_info}}
          @onRegisterApi={{self.onRegisterApi}}
        />
      </template>
    );

    this.submit().then((res) => {
      assert.deepEqual(res, {
        date: "2038-01-19",
        time: "03:15",
        datetime: "2038-01-19 03:15",
      });
    });
  });
});

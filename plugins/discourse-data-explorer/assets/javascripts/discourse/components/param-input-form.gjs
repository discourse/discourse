import Component from "@glimmer/component";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { isEmpty } from "@ember/utils";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import Form from "discourse/components/form";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import BooleanThree from "./param-input/boolean-three";
import CategoryIdInput from "./param-input/category-id-input";
import GroupInput from "./param-input/group-input";
import UserIdInput from "./param-input/user-id-input";
import UserListInput from "./param-input/user-list-input";

export class ParamValidationError extends Error {}

const layoutMap = {
  int: "int",
  bigint: "string",
  boolean: "boolean",
  string: "string",
  time: "time",
  date: "date",
  datetime: "datetime",
  double: "string",
  user_id: "user_id",
  post_id: "string",
  topic_id: "generic",
  category_id: "category_id",
  group_id: "group_list",
  badge_id: "generic",
  int_list: "generic",
  string_list: "generic",
  user_list: "user_list",
  group_list: "group_list",
};

export const ERRORS = {
  REQUIRED: i18n("form_kit.errors.required"),
  NOT_AN_INTEGER: i18n("form_kit.errors.not_an_integer"),
  NOT_A_NUMBER: i18n("form_kit.errors.not_a_number"),
  OVERFLOW_HIGH: i18n("form_kit.errors.too_high", { count: 2147484647 }),
  OVERFLOW_LOW: i18n("form_kit.errors.too_low", { count: -2147484648 }),
  INVALID: i18n("explorer.form.errors.invalid"),
  NO_SUCH_CATEGORY: i18n("explorer.form.errors.no_such_category"),
  NO_SUCH_GROUP: i18n("explorer.form.errors.no_such_group"),
  INVALID_DATE: (date) => i18n("explorer.form.errors.invalid_date", { date }),
  INVALID_TIME: (time) => i18n("explorer.form.errors.invalid_time", { time }),
};

function digitalizeCategoryId(value) {
  value = String(value || "");
  const isPositiveInt = /^\d+$/.test(value);
  if (!isPositiveInt && value.trim()) {
    return Category.asyncFindBySlugPath(dasherize(value))
      .then((res) => res.id)
      .catch((err) => {
        if (err.jqXHR?.status === 404) {
          throw new ParamValidationError(
            `${ERRORS.NO_SUCH_CATEGORY}: ${value}`
          );
        } else {
          throw new Error(err.errorThrow || err.message);
        }
      });
  }
  return value;
}

function serializeValue(type, value) {
  switch (type) {
    case "string":
    case "int":
      return value != null ? String(value) : "";
    case "boolean":
      return String(value);
    case "group_list":
    case "user_list":
      return value?.join(",");
    case "group_id":
      return value[0];
    case "datetime":
      return value?.replaceAll("T", " ");
    default:
      return value?.toString();
  }
}

function validationOf(info) {
  switch (layoutMap[info.type]) {
    case "boolean":
      return info.nullable ? "required" : "";
    case "string":
    case "string_list":
    case "generic":
      return info.nullable ? "" : "required:trim";
    default:
      return info.nullable ? "" : "required";
  }
}

const components = {
  int: <template>
    <@field.Input @type="number" name={{@info.identifier}} />
  </template>,
  boolean: <template><@field.Checkbox name={{@info.identifier}} /></template>,
  boolean_three: BooleanThree,
  category_id: CategoryIdInput, // TODO
  user_id: UserIdInput,
  user_list: UserListInput,
  group_list: GroupInput,
  date: <template>
    <@field.Input @type="date" name={{@info.identifier}} />
  </template>,
  time: <template>
    <@field.Input @type="time" name={{@info.identifier}} />
  </template>,
  datetime: <template>
    <@field.Input @type="datetime-local" name={{@info.identifier}} />
  </template>,
  default: <template><@field.Input name={{@info.identifier}} /></template>,
};

function componentOf(info) {
  let type = layoutMap[info.type] || "generic";
  if (info.nullable && type === "boolean") {
    type = "boolean_three";
  }
  return components[type] || components.default;
}

export default class ParamInputForm extends Component {
  @service site;

  data = {};
  paramInfo = [];
  infoOf = {};
  form = null;

  promiseNormalizations = [];
  formLoaded = new Promise((res) => {
    this.__form_load_callback = res;
  });

  constructor() {
    super(...arguments);
    this.initializeParams();

    this.args.onRegisterApi?.({
      submit: this.submit,
      allNormalized: Promise.allSettled(this.promiseNormalizations),
    });
  }

  initializeParams() {
    this.args.paramInfo.forEach((info) => {
      // Skip internal types - they are auto-injected server-side
      if (info.internal) {
        return;
      }

      const identifier = info.identifier;
      const pinfo = this.createParamInfo(info);

      this.paramInfo.push(pinfo);
      this.infoOf[identifier] = info;

      const normalized = this.getNormalizedValue(info);

      if (normalized instanceof Promise) {
        this.handlePromiseNormalization(normalized, pinfo);
      } else {
        this.data[identifier] = normalized;
      }
    });
  }

  createParamInfo(info) {
    return EmberObject.create({
      ...info,
      validation: validationOf(info),
      validate: this.validatorOf(info),
      component: componentOf(info),
    });
  }

  @action
  async addError(identifier, message) {
    await this.formLoaded;
    this.form.addError(identifier, {
      title: identifier,
      message,
    });
  }

  @action
  normalizeValue(info, value) {
    switch (info.type) {
      case "category_id":
        return digitalizeCategoryId(value);
      case "boolean":
        if (value == null || value === "#null") {
          return info.nullable ? "#null" : false;
        }
        return value === "true";
      case "group_id":
      case "group_list":
        const normalized = this.normalizeGroups(value);
        if (normalized.errorMsg) {
          this.addError(info.identifier, normalized.errorMsg);
        }
        return info.type === "group_id"
          ? normalized.value.slice(0, 1)
          : normalized.value;
      case "user_list":
        if (Array.isArray(value)) {
          return value || null;
        }
        return value?.split(",") || null;
      case "user_id":
        if (Array.isArray(value)) {
          return value[0];
        }
        return value;
      case "date":
        try {
          if (!value) {
            return null;
          }
          return moment(value).format("YYYY-MM-DD");
        } catch {
          this.addError(info.identifier, ERRORS.INVALID_DATE(String(value)));
          return null;
        }
      case "time":
        try {
          if (!value) {
            return null;
          }
          return moment(new Date(`1970/01/01 ${value}`).toISOString()).format(
            "HH:mm"
          );
        } catch {
          this.addError(info.identifier, ERRORS.INVALID_TIME(String(value)));
          return null;
        }
      case "datetime":
        try {
          if (!value) {
            return null;
          }
          return moment(new Date(value).toISOString()).format(
            "YYYY-MM-DD HH:mm"
          );
        } catch {
          this.addError(info.identifier, ERRORS.INVALID_TIME(String(value)));
          return null;
        }
      default:
        return value;
    }
  }

  getNormalizedValue(info) {
    const initialValues = this.args.initialValues;
    const identifier = info.identifier;
    return this.normalizeValue(
      info,
      initialValues && identifier in initialValues
        ? initialValues[identifier]
        : info.default
    );
  }

  handlePromiseNormalization(promise, pinfo) {
    this.promiseNormalizations.push(promise);
    pinfo.set("loading", true);
    this.data[pinfo.identifier] = null;

    promise
      .then((res) => this.form.set(pinfo.identifier, res))
      .catch((err) => this.addError(pinfo.identifier, err.message))
      .finally(() => pinfo.set("loading", false));
  }

  @action
  normalizeGroups(values) {
    values ||= [];
    if (typeof values === "string") {
      values = values.split(",");
    }

    const GroupNames = new Set(this.site.get("groups").map((g) => g.name));
    const GroupNameOf = Object.fromEntries(
      this.site.get("groups").map((g) => [g.id, g.name])
    );

    const valid_groups = [];
    const invalid_groups = [];

    for (const val of values) {
      if (GroupNames.has(val)) {
        valid_groups.push(val);
      } else if (GroupNameOf[Number(val)]) {
        valid_groups.push(GroupNameOf[Number(val)]);
      } else {
        invalid_groups.push(String(val));
      }
    }

    return {
      value: valid_groups,
      errorMsg:
        invalid_groups.length !== 0
          ? `${ERRORS.NO_SUCH_GROUP}: ${invalid_groups.join(", ")}`
          : null,
    };
  }

  getErrorFn(info) {
    const isPositiveInt = (value) => /^\d+$/.test(value);
    const VALIDATORS = {
      int: (value) => {
        if (value >= 2147483648) {
          return ERRORS.OVERFLOW_HIGH;
        }
        if (value <= -2147483649) {
          return ERRORS.OVERFLOW_LOW;
        }
        return null;
      },
      bigint: (value) => {
        if (isNaN(parseInt(value, 10))) {
          return ERRORS.NOT_A_NUMBER;
        }
        return /^-?\d+$/.test(value) ? null : ERRORS.NOT_AN_INTEGER;
      },
      boolean: (value) => {
        return /^Y|N|#null|true|false/.test(String(value))
          ? null
          : ERRORS.INVALID;
      },
      double: (value) => {
        if (isNaN(parseFloat(value))) {
          if (/^(-?)Inf(inity)?$/i.test(value) || /^(-?)NaN$/i.test(value)) {
            return null;
          }
          return ERRORS.NOT_A_NUMBER;
        }
        return null;
      },
      int_list: (value) => {
        return value.split(",").every((i) => /^(-?\d+|null)$/.test(i.trim()))
          ? null
          : ERRORS.INVALID;
      },
      post_id: (value) => {
        return isPositiveInt(value) ||
          /\d+\/\d+(\?u=.*)?$/.test(value) ||
          /\/t\/[^/]+\/(\d+)(\?u=.*)?/.test(value)
          ? null
          : ERRORS.INVALID;
      },
      topic_id: (value) => {
        return isPositiveInt(value) || /\/t\/[^/]+\/(\d+)/.test(value)
          ? null
          : ERRORS.INVALID;
      },
      category_id: (value) => {
        return this.site.categoriesById.get(Number(value))
          ? null
          : ERRORS.NO_SUCH_CATEGORY;
      },
      group_list: (value) => {
        return this.normalizeGroups(value).errorMsg;
      },
      group_id: (value) => {
        return this.normalizeGroups(value).errorMsg;
      },
    };
    return VALIDATORS[info.type] ?? (() => null);
  }

  validatorOf(info) {
    const getError = this.getErrorFn(info);
    return (name, value, { addError }) => {
      // skip require validation for we have used them in @validation
      if (isEmpty(value) || value == null) {
        return;
      }
      const message = getError(value);
      if (message != null) {
        addError(name, { title: info.identifier, message });
      }
    };
  }

  @action
  async submit() {
    // No visible params to validate - return empty object
    if (this.paramInfo.length === 0) {
      return {};
    }
    if (this.form == null) {
      throw "No form";
    }
    this.serializedData = null;
    await this.form.submit();
    if (this.serializedData == null) {
      throw new ParamValidationError("validation_failed");
    } else {
      return this.serializedData;
    }
  }

  @action
  onRegisterApi(form) {
    this.__form_load_callback();
    this.form = form;
  }

  @action
  onSubmit(data) {
    const serializedData = {};
    for (const [id, val] of Object.entries(data)) {
      serializedData[id] =
        serializeValue(this.infoOf[id].type, val) ?? undefined;
    }
    this.serializedData = serializedData;
  }

  <template>
    {{#if this.paramInfo.length}}
      <div class="query-params">
        <Form
          @data={{this.data}}
          @onRegisterApi={{this.onRegisterApi}}
          @onSubmit={{this.onSubmit}}
          class="params-form"
          as |form|
        >
          {{#each this.paramInfo as |info|}}
            <div class="param" data-test-param-name={{info.identifier}}>
              <form.Field
                @name={{info.identifier}}
                @title={{info.identifier}}
                @validation={{info.validation}}
                @validate={{info.validate}}
                as |field|
              >
                <info.component @field={{field}} @info={{info}} />
                <ConditionalLoadingSpinner
                  @condition={{info.loading}}
                  @size="small"
                />
              </form.Field>
            </div>
          {{/each}}
        </Form>
      </div>
    {{/if}}
  </template>
}

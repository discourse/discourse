import Component from "@glimmer/component";
import { array, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ManageTagsForm extends Component {
  formApi;

  initialData = {
    remove_all_tags: false,
    remove_tags: [],
    add_tags: [],
    replace_rows: [{ from: [], to: [] }],
  };

  constructor() {
    super(...arguments);
    this.args.onRegisterAction?.(this.triggerSubmit);
    this.args.setSubmitDisabled?.(true);
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  triggerSubmit() {
    this.formApi?.submit();
  }

  @action
  afterFieldSet(value, { set, name }) {
    set(name, value);
    this.args.setSubmitDisabled?.(this.#isEmpty());
  }

  @action
  blockedTagsFor(rows, index, side) {
    const tags = rows?.[index]?.[side];
    return tags?.length ? tags : undefined;
  }

  @action
  removeReplaceRow(collection, index) {
    collection.remove(index);
    // `collection.remove` doesn't re-key row errors, so drop them all.
    this.formApi.removeErrors();
    this.args.setSubmitDisabled?.(this.#isEmpty());
  }

  #isEmpty() {
    const removeAll = this.formApi.get("remove_all_tags") ?? false;
    const removeTags = this.formApi.get("remove_tags") ?? [];
    const addTags = this.formApi.get("add_tags") ?? [];
    const rows = this.formApi.get("replace_rows") ?? [];

    return (
      !removeAll &&
      addTags.length === 0 &&
      removeTags.length === 0 &&
      rows.every((row) => this.#replaceRowStatus(row) === "empty")
    );
  }

  @action
  validateReplaceRows(data, { addError, removeError }) {
    const title = i18n("topic_bulk_actions.manage_tags.replace.title");

    data.replace_rows.forEach((row, index) => {
      const fromName = `replace_rows.${index}.from`;
      const toName = `replace_rows.${index}.to`;
      removeError(fromName);
      removeError(toName);

      const status = this.#replaceRowStatus(row);
      if (status === "valid" || status === "empty") {
        return;
      }

      const message = this.#messageForStatus(status);

      if (status === "missing-from") {
        addError(fromName, { title, message });
      } else {
        addError(toName, { title, message });
      }
    });
  }

  @action
  onSubmit(data) {
    this.args.onPerform?.({ type: "manage_tags", ...this.#buildPayload(data) });
  }

  #replaceRowStatus(row) {
    const from = row?.from?.[0];
    const to = row?.to?.[0];

    if (!from && !to) {
      return "empty";
    }

    if (to && !from) {
      return "missing-from";
    }

    if (from && !to) {
      return "missing-to";
    }

    return "valid";
  }

  #messageForStatus(status) {
    switch (status) {
      case "missing-from":
        return i18n("topic_bulk_actions.manage_tags.replace.missing_from");
      case "missing-to":
        return i18n("topic_bulk_actions.manage_tags.replace.missing_to");
      default:
        return null;
    }
  }

  #buildPayload(data) {
    const removeAll = data.remove_all_tags;
    return {
      add_tag_ids: data.add_tags.map((tag) => tag.id),
      remove_tag_ids: removeAll ? [] : data.remove_tags.map((tag) => tag.id),
      remove_all_tags: removeAll,
      replace_tags: data.replace_rows
        .filter((row) => this.#replaceRowStatus(row) === "valid")
        .map(({ from, to }) => ({
          from_tag_id: from[0].id,
          to_tag_id: to[0].id,
        })),
    };
  }

  <template>
    <Form
      @data={{this.initialData}}
      @onSubmit={{this.onSubmit}}
      @onRegisterApi={{this.registerApi}}
      @validate={{this.validateReplaceRows}}
      class="manage-tags-form"
      as |form transientData|
    >

      <form.Container @format="full" class="manage-tags-form__remove-section">
        {{#if transientData.remove_all_tags}}
          <form.Alert @type="error" class="manage-tags-form__warning">
            {{trustHTML
              (i18n "topic_bulk_actions.manage_tags.remove.all_warning")
            }}
          </form.Alert>
        {{else}}
          <form.Field
            @name="remove_tags"
            @title={{i18n "topic_bulk_actions.manage_tags.remove.title"}}
            @description={{i18n
              "topic_bulk_actions.manage_tags.remove.description"
            }}
            @type="tag-chooser"
            @showOptional={{false}}
            @format="full"
            @onSet={{this.afterFieldSet}}
            as |field|
          >
            <field.Control />
          </form.Field>
        {{/if}}

        <form.Field
          @name="remove_all_tags"
          @title={{i18n "topic_bulk_actions.manage_tags.remove.all_toggle"}}
          @type="toggle"
          @showOptional={{false}}
          @onSet={{this.afterFieldSet}}
          as |field|
        >
          <field.Control />
        </form.Field>
      </form.Container>

      <form.Field
        @name="add_tags"
        @title={{i18n "topic_bulk_actions.manage_tags.add.title"}}
        @description={{i18n "topic_bulk_actions.manage_tags.add.description"}}
        @type="tag-chooser"
        @showOptional={{false}}
        @format="full"
        @onSet={{this.afterFieldSet}}
        as |field|
      >
        <field.Control @categoryId={{@categoryId}} />
      </form.Field>

      <form.Container
        @title={{i18n "topic_bulk_actions.manage_tags.replace.title"}}
        @subtitle={{i18n "topic_bulk_actions.manage_tags.replace.description"}}
        @format="full"
        class="manage-tags-form__replace"
      >
        <form.Collection @name="replace_rows" as |collection index|>
          <form.Row as |row|>
            <row.Col @size={{5}}>
              <collection.Field
                @name="from"
                @title={{i18n
                  "topic_bulk_actions.manage_tags.replace.from_placeholder"
                }}
                @showTitle={{false}}
                @type="tag-chooser"
                @format="full"
                @onSet={{this.afterFieldSet}}
                as |field|
              >
                <field.Control
                  @maximum={{1}}
                  @placeholder="topic_bulk_actions.manage_tags.replace.from_placeholder"
                  @blockedTags={{this.blockedTagsFor
                    transientData.replace_rows
                    index
                    "to"
                  }}
                />
              </collection.Field>
            </row.Col>

            <row.Col @size={{1}} class="manage-tags-form__replace-arrow">
              {{icon "arrow-right"}}
            </row.Col>

            <row.Col @size={{5}}>
              <collection.Field
                @name="to"
                @title={{i18n
                  "topic_bulk_actions.manage_tags.replace.to_placeholder"
                }}
                @showTitle={{false}}
                @type="tag-chooser"
                @format="full"
                @onSet={{this.afterFieldSet}}
                as |field|
              >
                <field.Control
                  @categoryId={{@categoryId}}
                  @maximum={{1}}
                  @placeholder="topic_bulk_actions.manage_tags.replace.to_placeholder"
                  @blockedTags={{this.blockedTagsFor
                    transientData.replace_rows
                    index
                    "from"
                  }}
                />
              </collection.Field>
            </row.Col>

            <row.Col @size={{1}}>
              <form.Button
                @icon="xmark"
                @action={{fn this.removeReplaceRow collection index}}
                @title="topic_bulk_actions.manage_tags.replace.remove_replacement"
                class="manage-tags-form__replace-row-remove"
              />
            </row.Col>
          </form.Row>
        </form.Collection>

        <form.Button
          @icon="plus"
          @translatedLabel={{i18n
            "topic_bulk_actions.manage_tags.replace.add_replacement"
          }}
          @action={{fn
            form.addItemToCollection
            "replace_rows"
            (hash from=(array) to=(array))
          }}
          class="btn-default manage-tags-form__replace-row-add"
        />
      </form.Container>
    </Form>
  </template>
}

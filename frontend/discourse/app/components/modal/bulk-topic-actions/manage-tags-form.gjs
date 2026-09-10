import Component from "@glimmer/component";
import { array, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import { bind } from "discourse/lib/decorators";
import { not } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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

  @bind
  mobilePlacementForReplaceRowTagChooser(rows, index) {
    const rowsBelow = rows.length - 1 - index;
    if (rowsBelow < 3) {
      return "top";
    }
    return null;
  }

  @action
  removeReplaceRow(collection, index) {
    collection.remove(index);
    // `collection.remove` doesn't re-key row errors, so drop them all.
    this.formApi.removeErrors();
    this.args.setSubmitDisabled?.(this.#isEmpty());
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
      class="manage-tags-form"
      @data={{this.initialData}}
      @onRegisterApi={{this.registerApi}}
      @onSubmit={{this.onSubmit}}
      @validate={{this.validateReplaceRows}}
      as |form transientData|
    >

      <form.Container class="manage-tags-form__remove-section" @format="full">
        {{#if transientData.remove_all_tags}}
          <form.Alert class="manage-tags-form__warning" @type="error">
            {{trustHTML
              (i18n "topic_bulk_actions.manage_tags.remove.all_warning")
            }}
          </form.Alert>
        {{else}}
          <form.Field
            @description={{i18n
              "topic_bulk_actions.manage_tags.remove.description"
            }}
            @format="full"
            @name="remove_tags"
            @onSet={{this.afterFieldSet}}
            @showOptional={{false}}
            @title={{i18n "topic_bulk_actions.manage_tags.remove.title"}}
            @type="tag-chooser"
            as |field|
          >
            <field.Control @showAllTags={{true}} />
          </form.Field>
        {{/if}}

        <form.Field
          @name="remove_all_tags"
          @onSet={{this.afterFieldSet}}
          @showOptional={{false}}
          @title={{i18n "topic_bulk_actions.manage_tags.remove.all_toggle"}}
          @type="toggle"
          as |field|
        >
          <field.Control />
        </form.Field>
      </form.Container>

      <form.Field
        @description={{i18n "topic_bulk_actions.manage_tags.add.description"}}
        @format="full"
        @name="add_tags"
        @onSet={{this.afterFieldSet}}
        @showOptional={{false}}
        @title={{i18n "topic_bulk_actions.manage_tags.add.title"}}
        @type="tag-chooser"
        as |field|
      >
        <field.Control
          @categoryId={{@categoryId}}
          @showAllTags={{not @categoryId}}
        />
      </form.Field>

      <form.Container
        class="manage-tags-form__replace"
        @format="full"
        @subtitle={{i18n "topic_bulk_actions.manage_tags.replace.description"}}
        @title={{i18n "topic_bulk_actions.manage_tags.replace.title"}}
      >
        <form.Collection @name="replace_rows" as |collection index|>
          <form.Row as |row|>
            <row.Col @size={{5}}>
              <collection.Field
                @format="full"
                @name="from"
                @onSet={{this.afterFieldSet}}
                @showTitle={{false}}
                @title={{i18n
                  "topic_bulk_actions.manage_tags.replace.from_placeholder"
                }}
                @type="tag-chooser"
                as |field|
              >
                <field.Control
                  @blockedTags={{this.blockedTagsFor
                    transientData.replace_rows
                    index
                    "to"
                  }}
                  @maximum={{1}}
                  @mobilePlacement={{this.mobilePlacementForReplaceRowTagChooser
                    transientData.replace_rows
                    index
                  }}
                  @placeholder="topic_bulk_actions.manage_tags.replace.from_placeholder"
                  @showAllTags={{true}}
                />
              </collection.Field>
            </row.Col>

            <row.Col class="manage-tags-form__replace-arrow" @size={{1}}>
              {{dIcon "arrow-right"}}
            </row.Col>

            <row.Col @size={{5}}>
              <collection.Field
                @format="full"
                @name="to"
                @onSet={{this.afterFieldSet}}
                @showTitle={{false}}
                @title={{i18n
                  "topic_bulk_actions.manage_tags.replace.to_placeholder"
                }}
                @type="tag-chooser"
                as |field|
              >
                <field.Control
                  @blockedTags={{this.blockedTagsFor
                    transientData.replace_rows
                    index
                    "from"
                  }}
                  @categoryId={{@categoryId}}
                  @maximum={{1}}
                  @mobilePlacement={{this.mobilePlacementForReplaceRowTagChooser
                    transientData.replace_rows
                    index
                  }}
                  @placeholder="topic_bulk_actions.manage_tags.replace.to_placeholder"
                  @showAllTags={{not @categoryId}}
                />
              </collection.Field>
            </row.Col>

            <row.Col @size={{1}}>
              <form.Button
                class="manage-tags-form__replace-row-remove"
                @action={{fn this.removeReplaceRow collection index}}
                @icon="xmark"
                @title="topic_bulk_actions.manage_tags.replace.remove_replacement"
              />
            </row.Col>
          </form.Row>
        </form.Collection>

        <form.Button
          class="btn-default manage-tags-form__replace-row-add"
          @action={{fn
            form.addItemToCollection
            "replace_rows"
            (hash from=(array) to=(array))
          }}
          @icon="plus"
          @translatedLabel={{i18n
            "topic_bulk_actions.manage_tags.replace.add_replacement"
          }}
        />
      </form.Container>
    </Form>
  </template>
}

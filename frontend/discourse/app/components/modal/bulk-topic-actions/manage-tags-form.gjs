import Component from "@glimmer/component";
import { array, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import TagChooser from "discourse/select-kit/components/tag-chooser";
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
  onReplaceTagChange(field, side, tags) {
    if (side === "from") {
      field.set({ from: tags, to: field.value.to });
    } else {
      field.set({ from: field.value.from, to: tags });
    }
  }

  @action
  removeReplaceRow(collection, index) {
    collection.remove(index);
    // `collection.remove` doesn't re-key row errors, so drop them all.
    this.formApi.removeErrors();
  }

  @action
  validateReplaceRow(name, value, { addError }) {
    const status = this.#replaceRowStatus(value);
    if (status === "valid" || status === "empty") {
      return;
    }

    addError(name, {
      title: i18n("topic_bulk_actions.manage_tags.replace.title"),
      message: this.#messageForStatus(status),
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

    if (from.id === to.id) {
      return "same-tag";
    }

    return "valid";
  }

  #messageForStatus(status) {
    switch (status) {
      case "missing-from":
        return i18n("topic_bulk_actions.manage_tags.replace.missing_from");
      case "missing-to":
        return i18n("topic_bulk_actions.manage_tags.replace.missing_to");
      case "same-tag":
        return i18n("topic_bulk_actions.manage_tags.replace.same_tag");
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
      class="manage-tags-form"
      as |form transientData|
    >
      <form.Section
        @title={{i18n "topic_bulk_actions.manage_tags.remove.title"}}
        @subtitle={{i18n "topic_bulk_actions.manage_tags.remove.description"}}
        class="manage-tags-section manage-tags-section--remove"
      >
        <:header>
          <form.Field
            @name="remove_all_tags"
            @title={{i18n "topic_bulk_actions.manage_tags.remove.all_toggle"}}
            @type="toggle"
            @showOptional={{false}}
            as |field|
          >
            <field.Control />
          </form.Field>
        </:header>

        <:default>
          {{#if transientData.remove_all_tags}}
            <form.Alert
              @type="error"
              class="manage-tags-section__warning"
            >{{trustHTML
                (i18n "topic_bulk_actions.manage_tags.remove.all_warning")
              }}</form.Alert>
          {{else}}
            <form.Field
              @name="remove_tags"
              @title={{i18n "topic_bulk_actions.manage_tags.remove.title"}}
              @showTitle={{false}}
              @type="tag-chooser"
              @format="full"
              as |field|
            >
              <field.Control />
            </form.Field>
          {{/if}}
        </:default>
      </form.Section>

      <form.Section
        @title={{i18n "topic_bulk_actions.manage_tags.add.title"}}
        @subtitle={{i18n "topic_bulk_actions.manage_tags.add.description"}}
        class="manage-tags-section manage-tags-section--add"
      >
        <form.Field
          @name="add_tags"
          @title={{i18n "topic_bulk_actions.manage_tags.add.title"}}
          @showTitle={{false}}
          @type="tag-chooser"
          @format="full"
          as |field|
        >
          <field.Control @categoryId={{@categoryId}} />
        </form.Field>
      </form.Section>

      <form.Section
        @title={{i18n "topic_bulk_actions.manage_tags.replace.title"}}
        @subtitle={{i18n "topic_bulk_actions.manage_tags.replace.description"}}
        class="manage-tags-section manage-tags-section--replace"
      >
        <form.Collection @name="replace_rows" as |collection index|>
          <form.Container class="manage-tags-replace-row">
            <collection.Field
              @title={{i18n "topic_bulk_actions.manage_tags.replace.title"}}
              @showTitle={{false}}
              @type="custom"
              @format="full"
              @validate={{this.validateReplaceRow}}
              as |field|
            >
              <field.Control>
                <TagChooser
                  @tags={{field.value.from}}
                  @onChange={{fn this.onReplaceTagChange field "from"}}
                  @options={{hash
                    maximum=1
                    filterPlaceholder="topic_bulk_actions.manage_tags.replace.from_placeholder"
                  }}
                />

                <span
                  class="manage-tags-replace-row__arrow"
                  aria-hidden="true"
                />

                <TagChooser
                  @tags={{field.value.to}}
                  @onChange={{fn this.onReplaceTagChange field "to"}}
                  @categoryId={{@categoryId}}
                  @options={{hash
                    maximum=1
                    filterPlaceholder="topic_bulk_actions.manage_tags.replace.to_placeholder"
                  }}
                />

                <form.Button
                  @icon="xmark"
                  @action={{fn this.removeReplaceRow collection index}}
                  @title="topic_bulk_actions.manage_tags.replace.remove_replacement"
                  class="btn-transparent manage-tags-replace-row__remove"
                />
              </field.Control>
            </collection.Field>
          </form.Container>
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
          class="btn-default manage-tags-replace-row__add"
        />
      </form.Section>
    </Form>
  </template>
}

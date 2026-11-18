import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import { isEmpty } from "@ember/utils";
import { addUniqueValueToArray } from "discourse/lib/array-tools";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

const INPUT_DELIMITER = "\n";
const NEW_ENTRY = Symbol("new entry");

const RevealToggle = <template>
  <DButton
    class="btn-default btn-small secret-value-list__reveal"
    @action={{@onToggle}}
    @ariaLabel="admin.settings.unmask"
    @icon={{if @masked "far-eye" "far-eye-slash"}}
  />
</template>;

export default class SecretValueList extends Component {
  @tracked newKey;
  @tracked newSecret;

  isMasked = (entry) => this.args.isSecret && !this.#revealedEntries.has(entry);

  #revealedEntries = trackedSet();

  @cached
  get collection() {
    return this.#splitValues(this.args.values, INPUT_DELIMITER);
  }

  @action
  changeKey(index, event) {
    const newValue = event.target.value;

    if (this.#checkInvalidInput(newValue)) {
      return;
    }

    this.#replaceValue(index, newValue, "key");
  }

  @action
  changeSecret(index, event) {
    const newValue = event.target.value;

    if (this.#checkInvalidInput(newValue)) {
      return;
    }

    this.#replaceValue(index, newValue, "secret");
  }

  @action
  addValue() {
    if (this.#checkInvalidInput([this.newKey, this.newSecret])) {
      return;
    }
    this.#addValue(this.newKey, this.newSecret);

    this.newKey = "";
    this.newSecret = "";
    this.#revealedEntries.delete(NEW_ENTRY);
  }

  @action
  removeValue(value) {
    this.#revealedEntries.delete(value.key);
    this.#removeValue(value);
  }

  @action
  toggleReveal(entry) {
    if (!this.#revealedEntries.delete(entry)) {
      this.#revealedEntries.add(entry);
    }
  }

  #checkInvalidInput(inputs) {
    for (const input of inputs) {
      if (isEmpty(input) || input.includes("|")) {
        this.args.setValidationMessage(
          i18n("admin.site_settings.secret_list.invalid_input")
        );
        return true;
      }
    }

    if (this.collection.some((item) => item.key.trim() === inputs[0].trim())) {
      this.args.setValidationMessage(
        i18n("admin.site_settings.secret_list.already_exists", {
          key: inputs[0],
        })
      );
      return true;
    }

    this.args.setValidationMessage(null);
  }

  #addValue(value, secret) {
    const updatedCollection = addUniqueValueToArray(
      [...this.collection],
      {
        key: value,
        secret,
      },
      (item) => item.key
    );
    this.#saveValues(updatedCollection);
  }

  #removeValue(value) {
    const updatedCollection = [...this.collection].filter(
      (item) => !(item.key === value.key && item.secret === value.secret)
    );
    this.#saveValues(updatedCollection);
  }

  #replaceValue(index, newValue, keyName) {
    const updatedCollection = [...this.collection];

    const item = updatedCollection[index];
    set(item, keyName, newValue);

    this.#saveValues(updatedCollection);
  }

  #saveValues(updatedCollection) {
    this.args.changeValueCallback(
      updatedCollection
        .map(function (elem) {
          return `${elem.key}|${elem.secret}`;
        })
        .join(INPUT_DELIMITER)
    );
  }

  #splitValues(values, delimiter) {
    if (values && values.length) {
      const keys = ["key", "secret"];
      const res = [];
      values.split(delimiter).forEach(function (str) {
        const object = {};
        str.split("|").forEach(function (a, i) {
          object[keys[i]] = a;
        });
        res.push(object);
      });

      return res;
    } else {
      return [];
    }
  }

  <template>
    <div class="value-list secret-value-list">
      {{#if this.collection}}
        <div class="values">
          {{#each this.collection key="@index" as |value index|}}
            <div class="value" data-index={{index}}>
              <DButton
                class="btn-default remove-value-btn btn-small"
                @action={{fn this.removeValue value}}
                @icon="xmark"
              />
              <Input
                class="value-input"
                @value={{value.key}}
                {{on "focusout" (fn this.changeKey index)}}
              />
              <Input
                class="value-input secret"
                @type={{if (this.isMasked value.key) "password" "text"}}
                @value={{value.secret}}
                {{on "focusout" (fn this.changeSecret index)}}
              />
              {{#if @isSecret}}
                <RevealToggle
                  @masked={{this.isMasked value.key}}
                  @onToggle={{fn this.toggleReveal value.key}}
                />
              {{/if}}
            </div>
          {{/each}}
        </div>
      {{/if}}

      <div class="value">
        <DTextField
          class="new-value-input key"
          @placeholder={{@placeholder.key}}
          @value={{this.newKey}}
        />
        <Input
          class="new-value-input secret"
          placeholder={{@placeholder.value}}
          @type={{if (this.isMasked NEW_ENTRY) "password" "text"}}
          @value={{this.newSecret}}
        />
        {{#if @isSecret}}
          <RevealToggle
            @masked={{this.isMasked NEW_ENTRY}}
            @onToggle={{fn this.toggleReveal NEW_ENTRY}}
          />
        {{/if}}
        <DButton
          class="add-value-btn btn-small"
          @action={{this.addValue}}
          @icon="plus"
        />
      </div>
    </div>
  </template>
}

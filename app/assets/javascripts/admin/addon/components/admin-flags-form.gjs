import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { TextArea } from "@ember/legacy-built-in-components";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import MultiSelect from "select-kit/components/multi-select";

export default class AdminFlagsForm extends Component {
  @service router;
  @service site;

  @tracked enabled = true;
  @tracked name;
  @tracked description;
  @tracked appliesTo;

  constructor() {
    super(...arguments);
    if (this.isUpdate) {
      this.name = this.args.flag.name;
      this.description = this.args.flag.description;
      this.appliesTo = this.args.flag.applies_to;
      this.enabled = this.args.flag.enabled;
    }
  }

  get isUpdate() {
    return this.args.flag;
  }

  get isValid() {
    return (
      !isEmpty(this.name) &&
      !isEmpty(this.description) &&
      !isEmpty(this.appliesTo)
    );
  }

  get header() {
    return this.isUpdate
      ? "admin.config_areas.flags.form.edit_header"
      : "admin.config_areas.flags.form.add_header";
  }

  get appliesToValues() {
    return this.site.valid_flag_applies_to_types.map((type) => {
      return {
        name: I18n.t(
          `admin.config_areas.flags.form.${type
            .toLowerCase()
            .replace("::", "_")}`
        ),
        id: type,
      };
    });
  }

  @action
  save() {
    this.isUpdate ? this.update() : this.create();
  }

  @bind
  create() {
    return ajax(`/admin/config/flags`, {
      type: "POST",
      data: this.#formData,
    })
      .then((response) => {
        this.site.flagTypes.push(response.flag);
        this.router.transitionTo("adminConfig.flags");
      })
      .catch((error) => {
        return popupAjaxError(error);
      });
  }

  @bind
  update() {
    return ajax(`/admin/config/flags/${this.args.flag.id}`, {
      type: "PUT",
      data: this.#formData,
    })
      .then((response) => {
        this.args.flag.name = response.flag.name;
        this.args.flag.description = response.flag.description;
        this.args.flag.applies_to = response.flag.applies_to;
        this.args.flag.enabled = response.flag.enabled;
        this.router.transitionTo("adminConfig.flags");
      })
      .catch((error) => {
        return popupAjaxError(error);
      });
  }

  @bind
  get #formData() {
    return {
      name: this.name,
      description: this.description,
      applies_to: this.appliesTo,
      enabled: this.enabled,
    };
  }

  <template>
    <div class="admin-config-area">
      <h2>{{i18n "admin.config_areas.flags.header"}}</h2>
      <LinkTo
        @route="adminConfig.flags"
        class="btn-default btn btn-icon-text btn-back"
      >
        {{dIcon "chevron-left"}}
        {{i18n "admin.config_areas.flags.back"}}
      </LinkTo>
      <div class="admin-config-area__primary-content admin-flag-form">
        <AdminConfigAreaCard @heading={{this.header}}>
          <div class="control-group">
            <label for="name">
              {{i18n "admin.config_areas.flags.form.name"}}
            </label>
            <Input
              name="name"
              @type="text"
              @value={{this.name}}
              maxlength="200"
              class="admin-flag-form__name"
            />
          </div>

          <div class="control-group">
            <label for="description">
              {{i18n "admin.config_areas.flags.form.description"}}
            </label>
            <TextArea
              @value={{this.description}}
              maxlength="1000"
              class="admin-flag-form__description"
            />
          </div>

          <div class="control-group">
            <label for="applies-to">
              {{i18n "admin.config_areas.flags.form.applies_to"}}
            </label>
            <MultiSelect
              @value={{this.appliesTo}}
              @content={{this.appliesToValues}}
              @options={{hash allowAny=false}}
              class="admin-flag-form__applies-to"
            />
          </div>

          <div class="control-group">
            <label class="checkbox-label admin-flag-form__enabled">
              <Input @type="checkbox" @checked={{this.enabled}} />
              {{i18n "admin.config_areas.flags.form.enabled"}}
            </label>
          </div>

          <div class="alert alert-info admin_flag_form__info">
            {{dIcon "info-circle"}}
            {{i18n "admin.config_areas.flags.form.alert"}}
          </div>

          <DButton
            @action={{this.save}}
            @label="admin.config_areas.flags.form.save"
            @ariaLabel="admin.config_areas.flags.form.save"
            @disabled={{not this.isValid}}
            class="btn-primary admin-flag-form__save"
          />
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}

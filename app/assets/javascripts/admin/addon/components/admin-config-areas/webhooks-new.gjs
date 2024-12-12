import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { concat, fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import { equal } from "@ember/object/computed";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import { eq } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import AdminFormRow from "admin/components/admin-form-row";
import ApiKeyUrlsModal from "admin/components/modal/api-key-urls";
import ComboBox from "select-kit/components/combo-box";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import DTooltip from "float-kit/components/d-tooltip";

export default class AdminConfigAreasWebhooksNew extends Component {
  @service router;
  @service modal;
  @service store;

  <template>
    <BackButton @route="adminWebHooks.index" @label="admin.web_hooks.back" />

    <div class="admin-config-area user-field">
      <div class="admin-config-area__primary-content">
        <div class="admin-config-area-card">
        </div>
      </div>
    </div>
  </template>
}

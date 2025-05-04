/* eslint-disable ember/no-test-import-export */

import { Textarea } from "@ember/component";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <DPageSubheader
      @descriptionLabel={{i18n
        "admin.config.email.sub_pages.advanced_test.header_description"
      }}
    />

    <div class="email-advanced-test">
      <label for="email">{{i18n "admin.email.advanced_test.email"}}</label>
      <Textarea name="email" @value={{@controller.email}} class="email-body" />
      <DButton
        @action={{@controller.run}}
        @label="admin.email.advanced_test.run"
      />
    </div>

    <ConditionalLoadingSpinner @condition={{@controller.loading}}>
      {{#if @controller.format}}
        <hr />
        <div class="text">
          <h3>{{i18n "admin.email.advanced_test.text"}}</h3>
          <pre class="full-reason">{{htmlSafe @controller.text}}</pre>
        </div>
        <hr />
        <div class="elided">
          <h3>{{i18n "admin.email.advanced_test.elided"}}</h3>
          <pre class="full-reason">{{htmlSafe @controller.elided}}</pre>
        </div>
      {{/if}}
    </ConditionalLoadingSpinner>
  </template>
);

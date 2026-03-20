import { Textarea } from "@ember/component";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default <template>
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

  <DConditionalLoadingSpinner @condition={{@controller.loading}}>
    {{#if @controller.format}}
      <hr />
      <div class="text">
        <h3>{{i18n "admin.email.advanced_test.text"}}</h3>
        <pre class="full-reason">{{trustHTML @controller.text}}</pre>
      </div>
      <hr />
      <div class="elided">
        <h3>{{i18n "admin.email.advanced_test.elided"}}</h3>
        <pre class="full-reason">{{trustHTML @controller.elided}}</pre>
      </div>
    {{/if}}
  </DConditionalLoadingSpinner>
</template>

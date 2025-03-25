import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <table class="table">
      <tbody>
        <tr>
          <th>{{i18n "admin.email.delivery_method"}}</th>
          <td>{{@controller.delivery_method}}</td>
        </tr>

        {{#each @controller.model.settings as |s|}}
          <tr>
            <th style="width: 25%">{{s.name}}</th>
            <td>{{s.value}}</td>
          </tr>
        {{/each}}
      </tbody>
    </table>

    <form>
      <div class="admin-controls">
        <div class="controls">
          <div class="inline-form">
            {{#if @controller.sendingEmail}}
              {{i18n "admin.email.sending_test"}}
            {{else}}
              <TextField
                @value={{@controller.testEmailAddress}}
                @placeholderKey="admin.email.test_email_address"
              />
              <DButton
                @action={{@controller.sendTestEmail}}
                @disabled={{@controller.sendTestEmailDisabled}}
                @label="admin.email.send_test"
                type="submit"
                class="btn-primary"
              />
              {{#if @controller.sentTestEmailMessage}}
                <span
                  class="result-message"
                >{{@controller.sentTestEmailMessage}}</span>
              {{/if}}
            {{/if}}
          </div>
        </div>
      </div>
    </form>
  </template>
);

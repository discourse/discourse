<label>{{i18n "admin.logs.screened_ips.form.label"}}</label>
<TextField
  @value={{this.ip_address}}
  @disabled={{this.formSubmitted}}
  @placeholderKey="admin.logs.screened_ips.form.ip_address"
  @autocorrect="off"
  @autocapitalize="off"
  class="ip-address-input"
/>

<ComboBox
  @content={{this.actionNames}}
  @value={{this.actionName}}
  @onChange={{fn (mut this.actionName)}}
/>

<DButton
  @action={{this.submitForm}}
  @disabled={{this.formSubmitted}}
  @label="admin.logs.screened_ips.form.add"
  type="submit"
  class="btn-default"
/>
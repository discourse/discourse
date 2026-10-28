import DFlashMessage from "discourse/ui-kit/d-flash-message";
import { i18n } from "discourse-i18n";

export default <template>
  <@form.Field
    @format="full"
    @name="name"
    @title={{i18n "blog.admin.theme_name"}}
    @type="input"
    @validation="required"
    as |field|
  ><field.Control @maxlength={{100}} /></@form.Field>
  <@form.Row as |row|>
    <row.Col @size={{4}}>
      <@form.Field
        @name="accent_color"
        @title={{i18n "blog.admin.accent"}}
        @type="color"
        @validation="required"
        as |field|
      ><field.Control /></@form.Field>
    </row.Col>
    <row.Col @size={{4}}>
      <@form.Field
        @name="paper_color"
        @title={{i18n "blog.admin.paper"}}
        @type="color"
        @validation="required"
        as |field|
      ><field.Control /></@form.Field>
    </row.Col>
    <row.Col @size={{4}}>
      <@form.Field
        @name="ink_color"
        @title={{i18n "blog.admin.ink"}}
        @type="color"
        @validation="required"
        as |field|
      ><field.Control /></@form.Field>
    </row.Col>
  </@form.Row>
  <@form.Field
    @description={{i18n "blog.admin.css_description"}}
    @format="full"
    @name="css"
    @title={{i18n "blog.admin.css"}}
    @type="code"
    as |field|
  ><field.Control @height={{280}} @lang="css" /></@form.Field>
  <details class="blog-theme-editor__javascript">
    <summary>{{i18n "blog.admin.js"}}</summary>
    <DFlashMessage @flash={{i18n "blog.admin.code_warning"}} @type="warning" />
    <@form.Field
      @description={{i18n "blog.admin.js_description"}}
      @format="full"
      @name="javascript"
      @showTitle={{false}}
      @title={{i18n "blog.admin.js"}}
      @type="code"
      as |field|
    ><field.Control @height={{280}} @lang="javascript" /></@form.Field>
  </details>
</template>

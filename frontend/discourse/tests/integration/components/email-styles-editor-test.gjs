import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import EmailStylesEditor from "discourse/admin/components/email-styles-editor";
import EmailStyle from "discourse/admin/models/email-style";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

class DialogStub extends Service {
  yesNoConfirm(options) {
    options.didConfirm();
  }
}

module("Integration | Component | EmailStylesEditor", function (hooks) {
  setupRenderingTest(hooks);

  let aceSizing;

  hooks.beforeEach(function () {
    this.owner.register("service:dialog", DialogStub);
    this.site.set("user_themes", [
      { theme_id: 42, default: true, name: "Email showcase" },
    ]);
    this.siteSettings.enable_email_theme_header_and_footer = true;

    // ace only finishes its first render inside a sized element
    aceSizing = document.createElement("style");
    aceSizing.textContent = ".ace_editor { width: 300px; height: 200px; }";
    document.head.append(aceSizing);
  });

  hooks.afterEach(function () {
    aceSizing.remove();
  });

  test("resetting follows the edited field", async function (assert) {
    const styles = EmailStyle.create({
      css: "body { color: red; }",
      default_css: "body { color: red; }",
    });

    await render(
      <template>
        <EmailStylesEditor @fieldName="css" @styles={{styles}} />
      </template>
    );

    assert
      .dom(".email-styles-editor__theme-fields")
      .doesNotExist("the theme fields link is limited to the HTML template");
    assert
      .dom(".btn-default")
      .isDisabled("there is nothing to reset while css matches its default");

    styles.setField("css", "body { color: blue; }");
    await settled();

    assert.dom(".btn-default").isEnabled("an edited field can be reset");

    await click(".btn-default");

    assert.strictEqual(
      styles.css,
      "body { color: red; }",
      "resetting restores the default"
    );
    assert
      .dom(".btn-default")
      .isDisabled("the reset field matches its default again");
  });

  test("links the HTML template to the default theme email fields", async function (assert) {
    const styles = EmailStyle.create({
      html: "%{theme_email_header}%{email_content}%{theme_email_footer}",
      default_html:
        "%{theme_email_header}%{email_content}%{theme_email_footer}",
    });

    await render(
      <template>
        <EmailStylesEditor @fieldName="html" @styles={{styles}} />
      </template>
    );

    assert
      .dom(".email-styles-editor__theme-fields")
      .includesText(
        i18n("admin.customize.email_style.theme_fields_description"),
        "explains how the default theme supplies the email fragments"
      );
    assert
      .dom(".email-styles-editor__theme-fields-link")
      .hasText(
        i18n("admin.customize.email_style.theme_fields_edit", {
          themeName: "Email showcase",
        }),
        "names the default theme"
      )
      .hasAttribute(
        "href",
        "/admin/customize/themes/42/email_header/email_header/edit",
        "links directly to the theme email header editor"
      );
  });

  test("links to read-only theme fields when email fragments are disabled", async function (assert) {
    this.siteSettings.enable_email_theme_header_and_footer = false;
    const styles = EmailStyle.create({
      html: "%{theme_email_header}%{email_content}%{theme_email_footer}",
      default_html:
        "%{theme_email_header}%{email_content}%{theme_email_footer}",
    });

    await render(
      <template>
        <EmailStylesEditor @fieldName="html" @styles={{styles}} />
      </template>
    );

    assert
      .dom(".email-styles-editor__theme-fields")
      .includesText(
        i18n("admin.customize.email_style.theme_fields_disabled"),
        "explains that theme email fragments are disabled"
      );
    assert.dom(".email-styles-editor__theme-fields-link").hasText(
      i18n("admin.customize.email_style.theme_fields_view", {
        themeName: "Email showcase",
      }),
      "offers to view the disabled fields"
    );
  });
});

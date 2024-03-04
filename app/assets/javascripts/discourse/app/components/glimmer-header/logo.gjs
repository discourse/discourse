import getURL from "discourse-common/lib/get-url";
import and from "truth-helpers/helpers/and";
import eq from "truth-helpers/helpers/eq";
import notEq from "truth-helpers/helpers/not-eq";

const Logo = <template>
  {{#if (and @darkUrl (notEq @url @darkUrl))}}
    <picture>
      <source srcset={{getURL @darkUrl}} media="(prefers-color-scheme: dark)" />
      <img
        id="site-logo"
        class={{@key}}
        src={{getURL @url}}
        width={{if (eq @key "logo-small") "36"}}
        alt={{@title}}
      />
    </picture>
  {{else}}
    <img
      id="site-logo"
      class={{@key}}
      src={{getURL @url}}
      width={{if (eq @key "logo-small") "36"}}
      alt={{@title}}
    />
  {{/if}}
</template>;

export default Logo;

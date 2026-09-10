import dIcon from "discourse/ui-kit/helpers/d-icon";
import Logo from "./logo";

const HomeLogoContents = <template>
  {{#if @minimized}}
    {{#if @logoSmallUrl}}
      <Logo
        @darkUrl={{@logoSmallUrlDark}}
        @key="logo-small"
        @title={{@title}}
        @url={{@logoSmallUrl}}
      />
    {{else}}
      {{dIcon "house"}}
    {{/if}}
  {{else if @showMobileLogo}}
    <Logo
      @darkUrl={{@mobileLogoUrlDark}}
      @key="logo-mobile"
      @title={{@title}}
      @url={{@mobileLogoUrl}}
    />
  {{else if @logoUrl}}
    <Logo
      @darkUrl={{@logoUrlDark}}
      @key="logo-big"
      @title={{@title}}
      @url={{@logoUrl}}
    />
  {{else}}
    <div class="text-logo" id="site-text-logo">
      {{@title}}
    </div>
  {{/if}}
</template>;

export default HomeLogoContents;

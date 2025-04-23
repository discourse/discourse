import icon from "discourse/helpers/d-icon";
import Logo from "./logo";

const HomeLogoContents = <template>
  {{#if @minimized}}
    {{#if @logoSmallUrl}}
      <Logo
        @key="logo-small"
        @url={{@logoSmallUrl}}
        @title={{@title}}
        @darkUrl={{@logoSmallUrlDark}}
      />
    {{else}}
      {{icon "house"}}
    {{/if}}
  {{else if @showMobileLogo}}
    <Logo
      @key="logo-mobile"
      @url={{@mobileLogoUrl}}
      @title={{@title}}
      @darkUrl={{@mobileLogoUrlDark}}
    />
  {{else if @logoUrl}}
    <Logo
      @key="logo-big"
      @url={{@logoUrl}}
      @title={{@title}}
      @darkUrl={{@logoUrlDark}}
    />
  {{else}}
    <div id="site-text-logo" class="text-logo">
      {{@title}}
    </div>
  {{/if}}
</template>;

export default HomeLogoContents;

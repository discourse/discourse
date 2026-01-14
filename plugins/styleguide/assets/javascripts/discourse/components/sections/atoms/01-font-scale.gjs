import HighlightedCode from "discourse/admin/components/highlighted-code";
import { i18n } from "discourse-i18n";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const FontScale = <template>
  <div class="section-description">
    <p>
      Discourse users can select from 4 different text sizes in their user
      settings, by default these are:
      <ul>
        <li>Smaller: 14px</li>
        <li>Normal (default): 15px</li>
        <li>Larger: 17px</li>
        <li>Largest: 19px</li>
      </ul>
    </p>
    <p>
      If you'd like to increase the font size of your entire Discourse
      community, you can override the font-size of the HTML element. You can
      also provide different font sizes for the user text size settings defined
      above. The example below increases all text size options by 1px.
    </p>
    <HighlightedCode
      @code="html {
  font-size: 16px; // default font-size

  &.text-size-smaller {
    font-size: 15px;
  }
  &.text-size-larger {
    font-size: 18px;
  }
  &.text-size-largest {
    font-size: 20px;
  }
}"
      @lang="scss"
    />
    <p>
      If you want to scale the fonts of a specific element, you can use
      Discourse's font scaling variables. Using the variable system ensures
      you're using a consistent set of font-sizes throughout your community.
      <p>
        Changing the font-size of a parent element will proportionately scale
        the font sizes of all its children.
      </p>
      <HighlightedCode
        @code=".parent {
  font-size: var(--font-up-3);
  // Increases the relative font-size of this element and its children by 3 steps in the scale
  .child {
    // If this is set to var(--font-down-3) in Discourse's default CSS,
    // the parent font-size increase above would make this equivalent to
    // var(--font-0) (var(--font-down-3) + var(--font-up-3) = var(--font-0))
  }
}"
        @lang="scss"
      />
    </p>
  </div>

  <StyleguideExample @title="var(--font-up-6)">
    <p class="font-up-6">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-5)">
    <p class="font-up-5">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-4)">
    <p class="font-up-4">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-3)">
    <p class="font-up-3">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-2)">
    <p class="font-up-2">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-1)">
    <p class="font-up-1">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-0), 1em — base font">
    <p class="font-0">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-1)">
    <p class="font-down-1">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-2)">
    <p class="font-down-2">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-3)">
    <p class="font-down-3">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-4)">
    <p class="font-down-4">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-5)">
    <p class="font-down-5">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-6)">
    <p class="font-down-6">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>
</template>;

export default FontScale;

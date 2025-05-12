import { i18n } from "discourse-i18n";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const FontScale = <template>
  <div class="section-description">
    <p>
      Discourse users can select from 4 different text sizes in their user
      settings, by default these are:
      <pre>
      Smaller: 14px Normal: 15px
      <span
        >(default)</span>
      Larger: 17px Largest: 19px
    </pre>
    </p>

    <p>
      If you'd like to increase the font size of your entire Discourse
      community, you can override the font-size of the HTML element. You can
      also provide different font sizes for the user text size settings defined
      above. The example below increases all text size options by 1px.
      <pre>
      html {
      <span
          class="hljs-attribute"
        >font-size</span>: 16px;
      <span>// default font-size
        </span>
      &.text-size-smaller {
      <span
          class="hljs-attribute"
        >font-size</span>: 15px; } &.text-size-larger
      {
      <span
          class="hljs-attribute"
        >font-size</span>: 18px; } &.text-size-largest
      {
      <span
          class="hljs-attribute"
        >font-size</span>: 20px; } }
    </pre>
    </p>
    <p>
      If you want to scale the fonts of a specific element, you can use
      Discourse's font scaling variables. Using the variable system ensures
      you're using a consistent set of font-sizes throughout your community.
      <p>
        Changing the font-size of a parent element will proportionately scale
        the font sizes of all its children.
      </p>
      <pre>
      .parent {
      <span
          class="hljs-attribute"
        >font-size</span>: var(--font-up-3);
      <span>// Increases the
          relative font-size of this element and its children by 3 steps in the
          scale</span>
      .child {
      <span>// If this is set to
          var(--font-down-3) in Discourse's default CSS, the parent font-size
          increase above would make this equivalent to var(--font-0)
          (var(--font-down-3) + var(--font-up-3) = var(--font-0))</span>
      } }
    </pre>
    </p>
  </div>

  <StyleguideExample @title="var(--font-up-6), 2.296em">
    <p class="font-up-6">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-5), 2em">
    <p class="font-up-5">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-4), 1.7511em">
    <p class="font-up-4">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-3), 1.5157em">
    <p class="font-up-3">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-2), 1.3195em">
    <p class="font-up-2">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-up-1), 1.1487em">
    <p class="font-up-1">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-0), 1em — base font">
    <p class="font-0">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-1), 0.8706em">
    <p class="font-down-1">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-2), 0.7579em">
    <p class="font-down-2">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-3), 0.6599em">
    <p class="font-down-3">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-4), 0.5745em">
    <p class="font-down-4">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-5), 0.5em">
    <p class="font-down-5">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>

  <StyleguideExample @title="var(--font-down-6), 0.4355em">
    <p class="font-down-6">{{i18n "styleguide.sections.typography.example"}}</p>
  </StyleguideExample>
</template>;

export default FontScale;

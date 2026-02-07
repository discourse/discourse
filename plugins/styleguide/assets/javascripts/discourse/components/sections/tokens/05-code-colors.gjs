import ColorExample from "discourse/plugins/styleguide/discourse/components/color-example";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const CodeColors = <template>
  <StyleguideExample @title="code sample">
    <pre class="code-colors-sample"><code><span
          class="hljs-keyword"
        >import</span>
        Component
        <span class="hljs-keyword">from</span>
        <span class="hljs-string">"@glimmer/component"</span>;

        <span class="hljs-keyword">export default</span>
        <span class="hljs-keyword">class</span>
        <span class="hljs-title">Example</span>
        <span class="hljs-keyword">extends</span>
        Component {
        <span class="hljs-comment">// A comment</span>
        <span class="hljs-keyword">get</span>
        <span class="hljs-title">value</span>() {
        <span class="hljs-keyword">return</span>
        <span class="hljs-number">42</span>; } }</code></pre>
  </StyleguideExample>

  <StyleguideExample @title="hljs variables">
    <section class="color-row">
      <ColorExample @color="hljs-bg" />
      <ColorExample @color="hljs-color" />
      <ColorExample @color="hljs-keyword" />
      <ColorExample @color="hljs-string" />
    </section>
    <section class="color-row">
      <ColorExample @color="hljs-title" />
      <ColorExample @color="hljs-comment" />
      <ColorExample @color="hljs-number" />
      <ColorExample @color="hljs-literal" />
    </section>
    <section class="color-row">
      <ColorExample @color="hljs-tag" />
      <ColorExample @color="hljs-attr" />
      <ColorExample @color="hljs-symbol" />
      <ColorExample @color="hljs-builtin" />
    </section>
  </StyleguideExample>
</template>;

export default CodeColors;

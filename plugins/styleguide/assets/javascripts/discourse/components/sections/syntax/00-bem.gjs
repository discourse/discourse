const Bem = <template>
  <div class="section-description">
    <p>
      The guidelines outlines below strive to bring structure and consistency to
      our classnames. Additionally, with this approach the nesting of css is
      firmly reduced. BEM stands for:
      <ul>
        <li>Block</li>
        <li>Element</li>
        <li>Modifier</li>
      </ul>
    </p>
    <p>We use a slightly modified version of the BEM classname format.</p>
    <h3>Block</h3>
    For example
    <strong><code>d-modal</code></strong>
    <p>A block is a standalone component. Blocks can be used within blocks. It
      should be a "top-level" element, which could be used in its entirety in
      another place of the app. It has no dependencies on any parent class.</p>
    <h3>Element</h3>
    For example
    <strong><code>d-modal__header</code></strong>
    <p>
      An element is a part of a block that can not be used outside that context.
      They because it depends on the parent class and can not be used standalone
      outside this context. In the example above, an element with class
      <code>d-modal__header</code>
      will only work within the d-modal block, but not when placed elsewhere.
    </p>
    <h3>Modifiers</h3>
    Examples
    <strong><code>--success</code>,
      <code>--large</code>,<code>--inline</code>,
      <code>--highlighted</code></strong>
    <p>
      A modifier is used mainly for changing the appearance, if different than
      the default. It is less than an element, and has no html structure of it
      own. Meaning, it can only exist when applied to an element (or potentially
      a block).
    </p>
    <p>In classic BEM, a modifier looks like:
      <code>d-modal__header--success</code>. This can quickly turn into very
      verbose HTML. Imagine an already long block-element name, for example:

      <p>
        <code>class="chat-message-creator__search-container"</code>
      </p>

      With classic BEM and 2 modifiers, it would look like this:

      <p>
        <code>class="chat-message-creator__search-container
          chat-message-creator__search-container--highlighted
          chat-message-creator__search-container--inline"</code>
      </p>

      To avoid this, we decouple our modifiers from the BE parts of the
      classnames and use them as separate classes. So in the previous case with
      2 modifiers this turns into:
      <p>
        <code>class="chat-message-creator__search-container --highlighted
          --inline"</code>
      </p>

      which is far more readable.
    </p>

    <h4>Special modifiers</h4>
    Some special prefixes are useful to identify modifiers as temporary states
    or condition. These are:
    <ul>
      <li><code>is-foo</code> = example: is-open</li>
      <li><code>has-foo</code> = example: has-errors</li>
    </ul>

    <h3>In Code</h3>
    <p>Even though the BEM convention avoids nesting, we can use SCSS to write
      the code nested. This is to taste, but I find it easier to read and write,
      because it will keep all relevant elements and modifiers grouped together
      and avoids unnecessary repetition of the block class.</p>
  </div>
</template>;

export default Bem;

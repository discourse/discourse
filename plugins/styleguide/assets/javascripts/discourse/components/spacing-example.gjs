const SpacingExample = <template>
  <section class="spacing-example">
    <div class="spacing-bar {{@spacing}}"></div>
    <div class="spacing-name">var(--{{@spacing}})</div>
  </section>
</template>;

export default SpacingExample;

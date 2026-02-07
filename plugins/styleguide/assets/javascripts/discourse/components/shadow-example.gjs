const ShadowExample = <template>
  <section class="shadow-example">
    <div class="shadow-card {{@shadow}}"></div>
    <div class="shadow-name">var(--{{@shadow}})</div>
  </section>
</template>;

export default ShadowExample;

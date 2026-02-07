const BorderRadiusExample = <template>
  <section class="border-radius-example">
    <div class="border-radius-box {{@radius}}"></div>
    <div class="border-radius-name">var(--{{@radius}})</div>
  </section>
</template>;

export default BorderRadiusExample;

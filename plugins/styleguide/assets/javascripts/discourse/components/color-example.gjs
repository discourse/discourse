const ColorExample = <template>
  <section class="color-example">
    <div class="color-bg {{@color}}"></div>
    <div class="color-name">var(--{{@color}})</div>
  </section>
</template>;

export default ColorExample;

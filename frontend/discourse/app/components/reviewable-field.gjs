const ReviewableField = <template>
  <div ...attributes>
    {{#if @value}}
      <div class={{@classes}}>
        <div class="name">{{@name}}</div>
        <div class="value">
          {{#if (has-block)}}{{yield @value}}{{else}}{{@value}}{{/if}}
        </div>
      </div>
    {{/if}}
  </div>
</template>;

export default ReviewableField;

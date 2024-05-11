const Col = <template>
  <div class="d-form__col --col-{{@size}}">
    {{yield}}
  </div>
</template>;

export default Col;

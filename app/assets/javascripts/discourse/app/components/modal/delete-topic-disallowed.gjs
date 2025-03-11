<DModal @closeModal={{@closeModal}}>
  <:body>
    <p>{{html-safe (i18n "post.controls.delete_topic_disallowed_modal")}}</p>
  </:body>
  <:footer>
    <DButton @action={{@closeModal}} class="btn-primary" @label="close" />
  </:footer>
</DModal>
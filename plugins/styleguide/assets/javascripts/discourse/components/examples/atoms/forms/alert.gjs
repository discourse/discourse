import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Alert @icon="pencil">
      You can edit this form.
    </form.Alert>
  </Form>
</template>

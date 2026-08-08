import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Section @title="Section title">
      Content
    </form.Section>
  </Form>
</template>

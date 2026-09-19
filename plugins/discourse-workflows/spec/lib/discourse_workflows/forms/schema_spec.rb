# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Forms::Schema do
  describe ".build" do
    it "maps workflow form fields to frontend field config and initial data" do
      schema =
        described_class.build(
          [
            {
              "field_label" => "Name",
              "field_type" => "text",
              "required" => true,
              "default_value" => "Ada",
              "placeholder" => "Your name",
            },
            { "field_label" => "Age", "field_type" => "number" },
            { "field_label" => "Email", "field_type" => "email" },
            {
              "field_label" => "Password",
              "field_type" => "password",
              "default_value" => "do-not-render",
            },
            { "field_label" => "Start Date", "field_type" => "date" },
            { "field_label" => "Agree", "field_type" => "checkbox", "default_value" => "true" },
            {
              "field_label" => "Plan",
              "field_name" => "plan_id",
              "field_type" => "dropdown",
              "options" => {
                "values" => [{ "value" => "basic" }, { "value" => "pro" }],
              },
            },
            {
              "field_label" => "Contact method",
              "field_name" => "contact_method",
              "field_type" => "radio",
              "options" => {
                "values" => [{ "value" => "email" }, { "value" => "phone" }],
              },
            },
            {
              "field_label" => "Tracking ID",
              "field_name" => "tracking_id",
              "field_type" => "hiddenField",
              "field_value" => "abc-123",
            },
            {
              "field_label" => "Intro",
              "field_type" => "html",
              "html" =>
                '<strong>Hello</strong><script>alert("x")</script><iframe src="https://example.com"></iframe><a href="javascript:alert(1)">Bad</a>',
            },
          ],
        )

      expect(schema[:data]).to eq(
        "name" => "Ada",
        "age" => "",
        "email" => "",
        "password" => "",
        "start_date" => "",
        "agree" => true,
        "plan_id" => "",
        "contact_method" => "",
      )
      html_field = schema[:fields].find { |field| field[:name] == "intro" }
      expect(html_field[:html]).to include("<strong>Hello</strong>")
      expect(html_field[:html]).not_to include("script")
      expect(html_field[:html]).not_to include("iframe")
      expect(html_field[:html]).not_to include("javascript")

      expect(schema[:fields]).to contain_exactly(
        {
          name: "name",
          title: "Name",
          type: "input",
          validation: "required",
          placeholder: "Your name",
          autofocus: false,
        },
        { name: "age", title: "Age", type: "input-number", autofocus: false },
        { name: "email", title: "Email", type: "input-email", autofocus: false },
        { name: "password", title: "Password", type: "password", autofocus: false },
        { name: "start_date", title: "Start Date", type: "input-date", autofocus: false },
        { name: "agree", title: "Agree", type: "checkbox", autofocus: false },
        {
          name: "plan_id",
          title: "Plan",
          type: "select",
          options: [{ value: "basic", label: "basic" }, { value: "pro", label: "pro" }],
          autofocus: false,
        },
        {
          name: "contact_method",
          title: "Contact method",
          type: "radio-group",
          options: [{ value: "email", label: "email" }, { value: "phone", label: "phone" }],
          autofocus: false,
        },
        { name: "intro", title: "Intro", type: "html", html: html_field[:html], autofocus: false },
      )
    end
  end
end

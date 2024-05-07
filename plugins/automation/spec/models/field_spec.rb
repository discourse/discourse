# frozen_string_literal: true

describe DiscourseAutomation::Field do
  describe "post field" do
    DiscourseAutomation::Scriptable.add("test_post_field") { field :foo, component: :post }

    fab!(:automation) { Fabricate(:automation, script: "test_post_field") }

    it "works with an empty value" do
      field =
        DiscourseAutomation::Field.create(automation: automation, component: "post", name: "foo")
      expect(field).to be_valid
    end

    it "works with a text value" do
      field =
        DiscourseAutomation::Field.create(
          automation: automation,
          component: "post",
          name: "foo",
          metadata: {
            value: "foo",
          },
        )
      expect(field).to be_valid
    end

    it "doesn’t work with an object value" do
      field =
        DiscourseAutomation::Field.create(
          automation: automation,
          component: "post",
          name: "foo",
          metadata: {
            value: {
              x: 1,
            },
          },
        )
      expect(field).to_not be_valid
    end
  end

  describe "period field" do
    DiscourseAutomation::Scriptable.add("test_period_field") { field :foo, component: :period }

    fab!(:automation) { Fabricate(:automation, script: "test_period_field") }

    it "works with an object value" do
      value = { interval: "2", frequency: "day" }
      field =
        DiscourseAutomation::Field.create(
          automation: automation,
          component: "period",
          name: "foo",
          metadata: {
            value: value,
          },
        )
      expect(field).to be_valid
    end
  end

  describe "choices field" do
    DiscourseAutomation::Scriptable.add("test_choices_field") { field :foo, component: :choices }

    fab!(:automation) { Fabricate(:automation, script: "test_choices_field") }

    it "works with a string value" do
      field =
        DiscourseAutomation::Field.create(
          automation: automation,
          component: "choices",
          name: "foo",
          metadata: {
            value: "some text",
          },
        )
      expect(field).to be_valid
    end

    it "works with an integer value" do
      field =
        DiscourseAutomation::Field.create(
          automation: automation,
          component: "choices",
          name: "foo",
          metadata: {
            value: 21,
          },
        )
      expect(field).to be_valid
    end

    it "does not work with an array value" do
      field =
        DiscourseAutomation::Field.create(
          automation: automation,
          component: "choices",
          name: "foo",
          metadata: {
            value: [1, 2, 3],
          },
        )
      expect(field).to_not be_valid
    end

    it "works with a nil value" do
      field =
        DiscourseAutomation::Field.create(
          automation: automation,
          component: "choices",
          name: "foo",
          metadata: {
            value: nil,
          },
        )
      expect(field).to be_valid
    end
  end
end

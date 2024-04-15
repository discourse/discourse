# frozen_string_literal: true

require "wizard"

RSpec.describe Wizard do
  fab!(:admin)

  before { SiteSetting.wizard_enabled = true }

  describe "defaults" do
    it "has default values" do
      wizard = Wizard.new(Fabricate.build(:moderator))
      expect(wizard.steps).to be_empty
      expect(wizard.user).to be_present
    end
  end

  describe "append_step" do
    let(:user) { Fabricate.build(:moderator) }
    let(:wizard) { Wizard.new(user) }
    let(:step1) { wizard.create_step("first-step") }
    let(:step2) { wizard.create_step("second-step") }

    it "works with a block format" do
      wizard.append_step("wat") { |step| expect(step).to be_present }

      expect(wizard.steps.size).to eq(1)
    end

    it "adds the step correctly" do
      expect(step1.index).to be_blank

      wizard.append_step(step1)
      expect(wizard.steps.size).to eq(1)
      expect(wizard.start).to eq(step1)
      expect(step1.next).to be_blank
      expect(step1.previous).to be_blank
      expect(step1.index).to eq(0)

      expect(step1.fields).to be_empty
      field = step1.add_field(id: "test", type: "text")
      expect(step1.fields).to eq([field])
    end

    it "sequences multiple steps" do
      wizard.append_step(step1)
      wizard.append_step(step2)

      expect(wizard.steps.size).to eq(2)
      expect(wizard.start).to eq(step1)
      expect(step1.next).to eq(step2)
      expect(step1.previous).to be_blank
      expect(step2.previous).to eq(step1)
      expect(step1.index).to eq(0)
      expect(step2.index).to eq(1)
    end
  end

  describe "remove_step" do
    let(:user) { Fabricate.build(:moderator) }
    let(:wizard) { Wizard.new(user) }
    let(:step1) { wizard.create_step("first-step") }
    let(:step2) { wizard.create_step("second-step") }
    let(:step3) { wizard.create_step("third-step") }

    before do
      wizard.append_step(step1)
      wizard.append_step(step2)
      wizard.append_step(step3)
    end

    it "does nothing if step id doesn't match any steps" do
      wizard.remove_step("nope")
      expect(wizard.steps).to contain_exactly(step1, step2, step3)
      expect(wizard.start).to eq(step1)
    end

    it "can remove the first step" do
      wizard.remove_step(step1.id)
      expect(wizard.steps).to contain_exactly(step2, step3)
      expect(step2.index).to eq(0)
      expect(step2.previous).to be_blank
      expect(step2.next).to eq(step3)

      expect(step3.index).to eq(1)
      expect(step3.previous).to eq(step2)
      expect(step3.next).to be_blank

      expect(wizard.start).to eq(step2)
    end

    it "can remove a middle step" do
      wizard.remove_step(step2.id)
      expect(wizard.steps).to contain_exactly(step1, step3)
      expect(step1.index).to eq(0)
      expect(step1.previous).to be_blank
      expect(step1.next).to eq(step3)

      expect(step3.index).to eq(1)
      expect(step3.previous).to eq(step1)
      expect(step3.next).to be_blank

      expect(wizard.start).to eq(step1)
    end

    it "can remove the last step" do
      wizard.remove_step(step3.id)
      expect(wizard.steps).to contain_exactly(step1, step2)
      expect(step1.index).to eq(0)
      expect(step1.previous).to be_blank
      expect(step1.next).to eq(step2)

      expect(step2.index).to eq(1)
      expect(step2.previous).to eq(step1)
      expect(step2.next).to be_blank

      expect(wizard.start).to eq(step1)
    end
  end

  describe ".exclude_step" do
    let(:user) { Fabricate.build(:moderator) }
    let(:wizard) { Wizard.new(user) }

    it "excludes steps even if they are added via append_step" do
      wizard.append_step("first") { |step| step.add_field(id: "another_element", type: "text") }

      Wizard.exclude_step("random-step123")

      wizard.append_step("random-step123") do |step|
        step.add_field(id: "another_element", type: "text")
      end
      wizard.append_step("finished")

      expect(wizard.steps.map(&:id)).to eq(%w[first finished])
    end
  end

  describe "#append_step with after specified" do
    let(:user) { Fabricate.build(:moderator) }
    let(:wizard) { Wizard.new(user) }

    it "inserts steps after the proper step" do
      wizard.append_step("first") { |step| step.add_field(id: "another_element", type: "text") }
      wizard.append_step("second") { |step| step.add_field(id: "another_element", type: "text") }
      wizard.append_step("actually-second", after: "first") do |step|
        step.add_field(id: "another_element", type: "text")
      end

      expect(wizard.steps.sort_by(&:index).map(&:id)).to eq(%w[first actually-second second])
      expect(wizard.steps.map(&:index).sort).to eq([0, 1, 2])
    end

    it "inserts steps at the end if the after value does not match an existing step" do
      wizard.append_step("first") { |step| step.add_field(id: "another_element", type: "text") }
      wizard.append_step("second") { |step| step.add_field(id: "another_element", type: "text") }
      wizard.append_step("should_be_last", after: "abcdefghi") do |step|
        step.add_field(id: "another_element", type: "text")
      end

      expect(wizard.steps.sort_by(&:index).map(&:id)).to eq(%w[first second should_be_last])
      expect(wizard.steps.map(&:index).sort).to eq([0, 1, 2])
    end

    it "inserts steps at the end" do
      wizard.append_step("first") { |step| step.add_field(id: "another_element", type: "text") }
      wizard.append_step("second") { |step| step.add_field(id: "another_element", type: "text") }
      wizard.append_step("last", after: "second") do |step|
        step.add_field(id: "another_element", type: "text")
      end

      expect(wizard.steps.sort_by(&:index).map(&:id)).to eq(%w[first second last])
      expect(wizard.steps.map(&:index).sort).to eq([0, 1, 2])
    end
  end

  describe "completed?" do
    let(:user) { Fabricate.build(:moderator) }
    let(:wizard) { Wizard.new(user) }

    it "is complete when all steps with fields have logs" do
      wizard.append_step("first") { |step| step.add_field(id: "element", type: "text") }

      wizard.append_step("second") { |step| step.add_field(id: "another_element", type: "text") }

      wizard.append_step("finished")

      expect(wizard.start.id).to eq("first")
      expect(wizard.completed_steps?("first")).to eq(false)
      expect(wizard.completed_steps?("second")).to eq(false)
      expect(wizard.completed?).to eq(false)

      updater = wizard.create_updater("first", element: "test")
      updater.update
      expect(wizard.start.id).to eq("second")
      expect(wizard.completed_steps?("first")).to eq(true)
      expect(wizard.completed?).to eq(false)

      updater = wizard.create_updater("second", element: "test")
      updater.update

      expect(wizard.completed_steps?("first")).to eq(true)
      expect(wizard.completed_steps?("second")).to eq(true)
      expect(wizard.completed_steps?("finished")).to eq(false)
      expect(wizard.completed?).to eq(true)

      # Once you've completed the wizard start at the beginning
      expect(wizard.start.id).to eq("first")
    end
  end

  describe "#requires_completion?" do
    def build_simple(user)
      wizard = Wizard.new(user)
      wizard.append_step("simple") { |step| step.add_field(id: "name", type: "text") }
      wizard
    end

    it "is false for anonymous" do
      expect(build_simple(nil).requires_completion?).to eq(false)
    end

    it "is false for regular users" do
      expect(build_simple(Fabricate.build(:user)).requires_completion?).to eq(false)
    end

    it "it's false when the wizard is disabled" do
      SiteSetting.wizard_enabled = false
      expect(build_simple(admin).requires_completion?).to eq(false)
    end

    it "its false when the wizard is bypassed" do
      SiteSetting.bypass_wizard_check = true
      expect(build_simple(admin).requires_completion?).to eq(false)
    end

    it "its automatically bypasses after you reach topic limit" do
      Fabricate(:topic)
      wizard = build_simple(admin)

      wizard.max_topics_to_require_completion = Topic.count - 1

      expect(wizard.requires_completion?).to eq(false)
      expect(SiteSetting.bypass_wizard_check).to eq(true)
    end

    it "it's true for the first admin who logs in" do
      second_admin = Fabricate(:admin)
      UserAuthToken.generate!(user_id: second_admin.id)

      expect(build_simple(admin).requires_completion?).to eq(false)
      expect(build_simple(second_admin).requires_completion?).to eq(true)
    end

    it "is false for staff when complete" do
      wizard = build_simple(admin)
      updater = wizard.create_updater("simple", name: "Evil Trout")
      updater.update

      expect(wizard.requires_completion?).to eq(false)

      # It's also false for another user
      wizard = build_simple(admin)
      expect(wizard.requires_completion?).to eq(false)
    end
  end
end

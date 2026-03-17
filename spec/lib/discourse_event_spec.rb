# frozen_string_literal: true

RSpec.describe DiscourseEvent do
  describe "#events" do
    it "defaults to {}" do
      begin
        original_events = DiscourseEvent.events
        DiscourseEvent.instance_variable_set(:@events, nil)
        expect(DiscourseEvent.events).to eq({})
      ensure
        DiscourseEvent.instance_variable_set(:@events, original_events)
      end
    end

    describe "key value" do
      it "defaults to an empty set" do
        expect(DiscourseEvent.events["event42"]).to eq(Set.new)
      end
    end
  end

  context "when calling events" do
    let(:harvey) { OpenStruct.new(name: "Harvey Dent", job: "District Attorney") }

    let(:event_handler) { Proc.new { |user| user.name = "Two Face" } }

    before { DiscourseEvent.on(:acid_face, &event_handler) }

    after { DiscourseEvent.off(:acid_face, &event_handler) }

    context "when event does not exist" do
      it "does not raise an error" do
        DiscourseEvent.trigger(:missing_event)
      end
    end

    context "when single event exists" do
      it "doesn't raise an error" do
        DiscourseEvent.trigger(:acid_face, harvey)
      end

      it "changes the name" do
        DiscourseEvent.trigger(:acid_face, harvey)
        expect(harvey.name).to eq("Two Face")
      end
    end

    context "when multiple events exist" do
      let(:event_handler_2) { Proc.new { |user| user.job = "Supervillain" } }

      before do
        DiscourseEvent.on(:acid_face, &event_handler_2)
        DiscourseEvent.trigger(:acid_face, harvey)
      end

      after { DiscourseEvent.off(:acid_face, &event_handler_2) }

      it "triggers both events" do
        expect(harvey.job).to eq("Supervillain")
        expect(harvey.name).to eq("Two Face")
      end
    end

    describe "#all_off" do
      let(:event_handler_2) { Proc.new { |user| user.job = "Supervillain" } }

      before { DiscourseEvent.on(:acid_face, &event_handler_2) }

      it "removes all handlers with a key" do
        harvey.job = "gardening"
        DiscourseEvent.all_off(:acid_face)
        DiscourseEvent.trigger(:acid_face, harvey) # Doesn't change anything
        expect(harvey.job).to eq("gardening")
      end
    end
  end

  describe ".trigger with continue_on_error" do
    let(:sprigatito) { OpenStruct.new(name: "Sprigatito", type: "Grass") }

    it "continues executing subsequent handlers when one raises" do
      ditto_handler = Proc.new { |cat| cat.name = "Ditto" }
      meowth_handler = Proc.new { raise "Team Rocket blasting off again" }
      evolve_handler = Proc.new { |cat| cat.type = "Grass/Dark" }

      DiscourseEvent.on(:evolve, &ditto_handler)
      DiscourseEvent.on(:evolve, &meowth_handler)
      DiscourseEvent.on(:evolve, &evolve_handler)

      DiscourseEvent.trigger(:evolve, sprigatito, continue_on_error: true)

      expect(sprigatito.name).to eq("Ditto")
      expect(sprigatito.type).to eq("Grass/Dark")
    ensure
      DiscourseEvent.off(:evolve, &ditto_handler)
      DiscourseEvent.off(:evolve, &meowth_handler)
      DiscourseEvent.off(:evolve, &evolve_handler)
    end
  end

  it "allows using kwargs" do
    begin
      handler =
        Proc.new do |name:, message:|
          expect(name).to eq("Supervillain")
          expect(message).to eq("Two Face")
        end

      DiscourseEvent.on(:acid_face, &handler)
      DiscourseEvent.trigger(:acid_face, name: "Supervillain", message: "Two Face")
    ensure
      DiscourseEvent.off(:acid_face, &handler)
    end
  end
end

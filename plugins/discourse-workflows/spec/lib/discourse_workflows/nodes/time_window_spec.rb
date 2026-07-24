# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TimeWindow::V1 do
  WEDNESDAY_UTC = Time.utc(2026, 7, 22, 10, 0)
  SATURDAY_UTC = Time.utc(2026, 7, 25, 10, 0)

  def wrap_items(*jsons)
    jsons.map { |json| { "json" => json } }
  end

  describe "#execute" do
    context "with day modes" do
      it "routes every item to the true branch with the all mode" do
        freeze_time SATURDAY_UTC

        items = wrap_items({ "id" => 1 }, { "id" => 2 })
        result = execute_node_output(configuration: { "day_mode" => "all" }, input_items: items)

        expect(result[0]).to eq(items)
        expect(result[1]).to be_empty
      end

      it "defaults to the all mode when day_mode is missing" do
        freeze_time SATURDAY_UTC

        items = wrap_items({ "id" => 1 })
        result = execute_node_output(configuration: {}, input_items: items)

        expect(result[0]).to eq(items)
      end

      it "matches weekdays only" do
        config = { "day_mode" => "weekdays" }
        items = wrap_items({ "id" => 1 })

        freeze_time WEDNESDAY_UTC
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        freeze_time SATURDAY_UTC
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end

      it "matches weekends only" do
        config = { "day_mode" => "weekends" }
        items = wrap_items({ "id" => 1 })

        freeze_time SATURDAY_UTC
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        freeze_time WEDNESDAY_UTC
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end

      it "matches specific days in custom mode" do
        config = { "day_mode" => "custom", "days" => [3] }
        items = wrap_items({ "id" => 1 })

        freeze_time WEDNESDAY_UTC
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        freeze_time SATURDAY_UTC
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end

      it "accepts custom days stored as strings" do
        freeze_time WEDNESDAY_UTC

        items = wrap_items({ "id" => 1 })
        config = { "day_mode" => "custom", "days" => %w[3] }
        result = execute_node_output(configuration: config, input_items: items)

        expect(result[0]).to eq(items)
      end

      it "routes everything to the false branch when custom days are empty" do
        freeze_time WEDNESDAY_UTC

        items = wrap_items({ "id" => 1 })
        config = { "day_mode" => "custom", "days" => [] }
        result = execute_node_output(configuration: config, input_items: items)

        expect(result[0]).to be_empty
        expect(result[1]).to eq(items)
      end

      it "raises on an unknown day mode" do
        freeze_time WEDNESDAY_UTC

        expect {
          execute_node_output(
            configuration: {
              "day_mode" => "banana",
            },
            input_items: wrap_items({ "id" => 1 }),
          )
        }.to raise_error(DiscourseWorkflows::NodeError, /banana/)
      end
    end

    context "with a time range" do
      it "ignores times when use_time_range is off" do
        freeze_time Time.utc(2026, 7, 22, 3, 0)

        items = wrap_items({ "id" => 1 })
        config = { "use_time_range" => false, "start_time" => "09:00", "end_time" => "17:00" }
        result = execute_node_output(configuration: config, input_items: items)

        expect(result[0]).to eq(items)
      end

      it "is start-inclusive and end-exclusive" do
        config = { "use_time_range" => true, "start_time" => "09:00", "end_time" => "17:00" }
        items = wrap_items({ "id" => 1 })

        { [8, 59] => 1, [9, 0] => 0, [16, 59] => 0, [17, 0] => 1 }.each do |(hour, minute), branch|
          freeze_time Time.utc(2026, 7, 22, hour, minute)
          result = execute_node_output(configuration: config, input_items: items)
          expect(result[branch]).to eq(items), "expected #{hour}:#{minute} on branch #{branch}"
        end
      end

      it "wraps past midnight when the end is before the start" do
        config = { "use_time_range" => true, "start_time" => "22:00", "end_time" => "06:00" }
        items = wrap_items({ "id" => 1 })

        {
          [23, 0] => 0,
          [3, 0] => 0,
          [22, 0] => 0,
          [12, 0] => 1,
          [6, 0] => 1,
        }.each do |(hour, minute), branch|
          freeze_time Time.utc(2026, 7, 22, hour, minute)
          result = execute_node_output(configuration: config, input_items: items)
          expect(result[branch]).to eq(items), "expected #{hour}:#{minute} on branch #{branch}"
        end
      end

      it "treats a midnight end as until the end of the day" do
        config = { "use_time_range" => true, "start_time" => "08:00", "end_time" => "00:00" }
        items = wrap_items({ "id" => 1 })

        freeze_time Time.utc(2026, 7, 22, 23, 59)
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        freeze_time Time.utc(2026, 7, 22, 7, 0)
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end

      it "matches nothing when start and end are equal" do
        freeze_time Time.utc(2026, 7, 22, 9, 0)

        items = wrap_items({ "id" => 1 })
        config = { "use_time_range" => true, "start_time" => "09:00", "end_time" => "09:00" }
        result = execute_node_output(configuration: config, input_items: items)

        expect(result[1]).to eq(items)
      end
    end

    context "with timezones" do
      it "evaluates the window in the configured timezone" do
        # Wednesday 22:00 UTC is Thursday 07:00 in Tokyo.
        freeze_time Time.utc(2026, 7, 22, 22, 0)

        items = wrap_items({ "id" => 1 })
        config = {
          "use_time_range" => true,
          "start_time" => "06:00",
          "end_time" => "08:00",
          "timezone" => "Asia/Tokyo",
        }

        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        result =
          execute_node_output(configuration: config.merge("timezone" => "UTC"), input_items: items)
        expect(result[1]).to eq(items)
      end

      it "flips the day of week with the timezone" do
        # Saturday 02:00 UTC is still Friday in Los Angeles.
        freeze_time Time.utc(2026, 7, 25, 2, 0)

        items = wrap_items({ "id" => 1 })
        config = { "day_mode" => "weekdays", "timezone" => "America/Los_Angeles" }

        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)
      end

      it "falls back to the workflow timezone" do
        freeze_time Time.utc(2026, 7, 25, 2, 0)

        workflow =
          Fabricate(
            :discourse_workflows_workflow,
            settings: {
              "timezone" => "America/Los_Angeles",
            },
          )
        items = wrap_items({ "id" => 1 })
        config = { "day_mode" => "weekdays" }

        result = execute_node_output(configuration: config, input_items: items, workflow: workflow)
        expect(result[0]).to eq(items)
      end

      it "prefers the node timezone over the workflow timezone" do
        freeze_time Time.utc(2026, 7, 25, 2, 0)

        workflow =
          Fabricate(
            :discourse_workflows_workflow,
            settings: {
              "timezone" => "America/Los_Angeles",
            },
          )
        items = wrap_items({ "id" => 1 })
        config = { "day_mode" => "weekdays", "timezone" => "UTC" }

        result = execute_node_output(configuration: config, input_items: items, workflow: workflow)
        expect(result[1]).to eq(items)
      end

      it "falls back to the site timezone without a workflow" do
        freeze_time Time.utc(2026, 7, 25, 2, 0)

        items = wrap_items({ "id" => 1 })
        result =
          execute_node_output(configuration: { "day_mode" => "weekdays" }, input_items: items)

        expect(result[1]).to eq(items)
      end

      it "raises on an invalid timezone" do
        freeze_time WEDNESDAY_UTC

        expect {
          execute_node_output(
            configuration: {
              "timezone" => "Mars/Olympus",
            },
            input_items: wrap_items({ "id" => 1 }),
          )
        }.to raise_error(DiscourseWorkflows::NodeError, %r{Mars/Olympus})
      end
    end

    context "with expressions" do
      it "resolves the time range per item" do
        freeze_time Time.utc(2026, 7, 22, 12, 0)

        items =
          wrap_items(
            { "id" => 1, "start" => "08:00", "end" => "18:00" },
            { "id" => 2, "start" => "13:00", "end" => "14:00" },
          )
        config = {
          "use_time_range" => true,
          "start_time" => "={{ $json.start }}",
          "end_time" => "={{ $json.end }}",
        }

        result = execute_node_output(configuration: config, input_items: items)

        expect(result[0].map { |item| item["json"]["id"] }).to eq([1])
        expect(result[1].map { |item| item["json"]["id"] }).to eq([2])
      end

      it "raises when an expression resolves to an invalid time" do
        freeze_time WEDNESDAY_UTC

        config = {
          "use_time_range" => true,
          "start_time" => "={{ $json.start }}",
          "end_time" => "18:00",
        }

        expect {
          execute_node_output(
            configuration: config,
            input_items: wrap_items({ "start" => "banana" }),
          )
        }.to raise_error(DiscourseWorkflows::NodeError, /banana/)
      end

      it "raises when an expression resolves to an invalid timezone" do
        freeze_time WEDNESDAY_UTC

        expect {
          execute_node_output(
            configuration: {
              "timezone" => "={{ $json.tz }}",
            },
            input_items: wrap_items({ "tz" => "Nowhere/Land" }),
          )
        }.to raise_error(DiscourseWorkflows::NodeError, %r{Nowhere/Land})
      end
    end
  end

  describe ".validate_configuration" do
    def validate(config)
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      errors
    end

    it "accepts a valid configuration" do
      errors =
        validate(
          "day_mode" => "custom",
          "days" => [1, 2],
          "use_time_range" => true,
          "start_time" => "09:00",
          "end_time" => "17:30",
          "timezone" => "Europe/Paris",
        )

      expect(errors).to be_empty
    end

    it "rejects an unknown day mode" do
      errors = validate("day_mode" => "banana")

      expect(errors[:base]).to include(
        I18n.t("discourse_workflows.errors.time_window.invalid_day_mode", mode: "banana"),
      )
    end

    it "requires days in custom mode" do
      errors = validate("day_mode" => "custom", "days" => [])

      expect(errors[:base]).to include(
        I18n.t("discourse_workflows.errors.time_window.days_required"),
      )
    end

    it "rejects out-of-range days" do
      errors = validate("day_mode" => "custom", "days" => [1, 9])

      expect(errors[:base]).to include(
        I18n.t("discourse_workflows.errors.time_window.invalid_days"),
      )
    end

    it "rejects malformed times" do
      errors = validate("use_time_range" => true, "start_time" => "25:99", "end_time" => "17:00")

      expect(errors[:base]).to include(
        I18n.t("discourse_workflows.errors.time_window.invalid_time_range"),
      )
    end

    it "requires times when the time range is enabled" do
      errors = validate("use_time_range" => true)

      expect(errors[:base]).to include(
        I18n.t("discourse_workflows.errors.time_window.invalid_time_range"),
      )
    end

    it "rejects equal start and end times" do
      errors = validate("use_time_range" => true, "start_time" => "09:00", "end_time" => "09:00")

      expect(errors[:base]).to include(
        I18n.t("discourse_workflows.errors.time_window.start_end_equal"),
      )
    end

    it "rejects an invalid timezone" do
      errors = validate("timezone" => "Mars/Olympus")

      expect(errors[:base]).to include(
        I18n.t("discourse_workflows.errors.time_window.invalid_timezone", timezone: "Mars/Olympus"),
      )
    end

    it "skips expression values" do
      errors =
        validate(
          "use_time_range" => true,
          "start_time" => "={{ $json.start }}",
          "end_time" => "={{ $json.end }}",
          "timezone" => "={{ $json.tz }}",
        )

      expect(errors).to be_empty
    end
  end
end

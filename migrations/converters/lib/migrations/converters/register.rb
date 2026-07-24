# frozen_string_literal: true

Migrations::CLI::Registry.register(
  name: "convert",
  command_class: "Migrations::Converters::CLI::ConvertCommand",
  description: "Convert a source dump into the IntermediateDB",
)

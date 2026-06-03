# frozen_string_literal: true

Migrations::CLI::Registry.register(
  name: "schema",
  command_class: "Migrations::Tooling::CLI::SchemaCommand",
  description: "Manage the IntermediateDB schema",
)

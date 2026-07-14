# frozen_string_literal: true

Migrations::CLI::Registry.register(
  name: "import",
  command_class: "Migrations::Importer::CLI::ImportCommand",
  description: "Import the IntermediateDB into a Discourse database",
)

Migrations::CLI::Registry.register(
  name: "upload",
  command_class: "Migrations::Importer::CLI::UploadCommand",
  description: "Import media uploads referenced by the IntermediateDB",
)

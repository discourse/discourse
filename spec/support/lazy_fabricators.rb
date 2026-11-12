# frozen_string_literal: true

module LazyFabricators
  FABRICATOR_PATTERN = /Fabricator\(\s*:([a-zA-Z0-9_]+)/

  def register(...)
    @registering_fabricator = true
    super
  ensure
    @registering_fabricator = false
  end

  def [](name)
    schematic = super
    return schematic if schematic || @registering_fabricator

    if (file = fabricator_files[name.to_sym]) && !loading_fabricator_files.include?(file)
      loading_fabricator_files << file
      begin
        Kernel.load(file)
      ensure
        loading_fabricator_files.delete(file)
      end
    end

    super
  end

  def empty?
    fabricator_files.empty? && super
  end

  private

  def fabricator_files
    @fabricator_files ||=
      Dir[Rails.root.join("spec/fabricators/*.rb")].each_with_object({}) do |file, files|
        File.read(file).scan(FABRICATOR_PATTERN).flatten.each { |name| files[name.to_sym] = file }
      end
  end

  def loading_fabricator_files
    @loading_fabricator_files ||= Set.new
  end
end

Fabrication::Schematic::Manager.prepend(LazyFabricators)

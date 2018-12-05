if ENV['DISCOURSE_DUMP_HEAP'] == "1"
  require 'objspace'
  ObjectSpace.trace_object_allocations_start
end

require 'rubygems'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])

if ENV['RAILS_ENV'] != 'production' && ENV['RAILS_ENV'] != 'profile'
  begin
    require 'bootsnap'
  rescue LoadError
    # not a strong requirement
  end

  if defined? Bootsnap
    Bootsnap.setup(
      cache_dir: 'tmp/cache',     # Path to your cache
      load_path_cache: true,      # Should we optimize the LOAD_PATH with a cache?
      autoload_paths_cache: true, # Should we optimize ActiveSupport autoloads with cache?
      disable_trace: false,       # Sets `RubyVM::InstructionSequence.compile_option = { trace_instruction: false }`
      compile_cache_iseq: true,   # Should compile Ruby code into ISeq cache?
      compile_cache_yaml: false   # Skip YAML cache for now, cause we were seeing issues with it
    )
  end
end

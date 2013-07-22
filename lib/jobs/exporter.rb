require_dependency 'export/json_encoder'
require_dependency 'export/export'
require_dependency 'import/import'

module Jobs

  class Exporter < Jobs::Base

    sidekiq_options retry: false

    def execute(args)
      raise Import::ImportInProgressError if Import::is_import_running?
      raise Export::ExportInProgressError if Export::is_export_running?

      @format = args[:format] || :json

      @output_base_filename = File.absolute_path( args[:filename] || File.join( Rails.root, 'tmp', "export-#{Time.now.strftime('%Y-%m-%d-%H%M%S')}" ) )
      @output_base_filename = @output_base_filename[0...-3] if @output_base_filename[-3..-1] == '.gz'
      @output_base_filename = @output_base_filename[0...-4] if @output_base_filename[-4..-1] == '.tar'

      @user = args[:user_id] ? User.where(id: args[:user_id].to_i).first : nil

      start_export
      @encoder.write_schema_info( source: 'discourse', version: Export.current_schema_version )
      ordered_models_for_export.each do |model|
        log "  #{model.table_name}"
        column_info = model.columns
        order_col = column_info.map(&:name).find {|x| x == 'id'} || order_columns_for(model)
        @encoder.write_table(model.table_name, column_info) do |num_rows_written|
          if order_col
            model.connection.select_rows("select * from #{model.table_name} order by #{order_col} limit #{batch_size} offset #{num_rows_written}")
          else
            # Take the rows in the order the database returns them
            log "WARNING: no order by clause is being used for #{model.name} (#{model.table_name}). Please update Jobs::Exporter order_columns_for for #{model.name}."
            model.connection.select_rows("select * from #{model.table_name} limit #{batch_size} offset #{num_rows_written}")
          end
        end
      end
      "#{@output_base_filename}.tar.gz"
    ensure
      finish_export
    end

    def ordered_models_for_export
      Export.models_included_in_export
    end

    def order_columns_for(model)
      @order_columns_for_hash ||= {
        'CategoryFeaturedTopic' => 'category_id, topic_id',
        'CategorySearchData'    => 'category_id',
        'PostOneboxRender'      => 'post_id, onebox_render_id',
        'PostReply'             => 'post_id, reply_id',
        'PostSearchData'        => 'post_id',
        'PostTiming'            => 'topic_id, post_number, user_id',
        'SiteContent'           => 'content_type',
        'TopicUser'             => 'topic_id, user_id',
        'UserSearchData'        => 'user_id',
        'View'                  => 'parent_id, parent_type, ip_address, viewed_at'
      }
      @order_columns_for_hash[model.name]
    end

    def batch_size
      1000
    end

    def start_export
      if @format == :json
        @encoder = Export::JsonEncoder.new
      else
        raise Export::FormatInvalidError
      end
      Export.set_export_started
      Discourse.enable_maintenance_mode
    end

    def finish_export
      if @encoder
        @encoder.finish
        create_tar_file
        @encoder.remove_tmp_directory('export')
      end
    ensure
      Export.set_export_is_not_running
      Discourse.disable_maintenance_mode
      send_notification
    end

    def create_tar_file
      filenames = @encoder.filenames

      FileUtils.cd( File.dirname(filenames.first) ) do
        `tar cvf #{@output_base_filename}.tar #{File.basename(filenames.first)}`
      end

      FileUtils.cd( File.join(Rails.root, 'public') ) do
        Upload.find_each do |upload|
          `tar rvf #{@output_base_filename}.tar #{upload.url[1..-1]}` unless upload.url[0,4] == 'http'
        end
      end

      `gzip #{@output_base_filename}.tar`

      true
    end

    def send_notification
      SystemMessage.new(@user).create('export_succeeded') if @user
      true
    end

  end

end

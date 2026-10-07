# frozen_string_literal: true
module NativeBrowserDownloads
  def initialize(...)
    super
    @download_mutex = Mutex.new
    @download_condition = ConditionVariable.new
    @downloads = {}
    @download_sequence = 0
    @downloads_closed = false
  end

  def expect_download(timeout: 30_000)
    start
    FileUtils.mkdir_p(@download_directory)
    sequence = @download_mutex.synchronize { @download_sequence }
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout / 1000.0
    yield
    @download_mutex.synchronize do
      loop do
        download = @downloads.values.find { |item| item.fetch(:sequence) > sequence }
        if download
          return(
            NativeDownload.new(
              self,
              guid: download.fetch(:guid),
              filename: download.fetch(:filename),
            )
          )
        end
        if @downloads_closed
          raise Playwright::Error.new(message: "Browser closed while waiting for a download")
        end
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        if timeout != 0 && remaining <= 0
          raise Playwright::TimeoutError.new(message: "Native download event timed out")
        end
        @download_condition.wait(@download_mutex, timeout == 0 ? nil : remaining)
      end
    end
  end

  def downloaded_file(guid)
    @download_mutex.synchronize do
      loop do
        download = @downloads[guid]
        if @downloads_closed || !download
          raise Playwright::Error.new(message: "Download no longer belongs to an active session")
        end
        raise Playwright::Error.new(message: "Download canceled") if download[:state] == "canceled"
        path = File.join(@download_directory, guid)
        return path if download[:state] == "completed" && File.file?(path)
        @download_condition.wait(@download_mutex, 0.05)
      end
    end
  end

  def reset!
    if @input
      pending =
        @download_mutex.synchronize do
          @downloads.values.select { |item| item[:state] == "inProgress" }.map(&:dup)
        end
      pending.each do |download|
        params = { guid: download.fetch(:guid) }
        params[:browserContextId] = download[:context_id] if download[:context_id]
        command("Browser.cancelDownload", params, browser: true)
      end
      @download_mutex.synchronize do
        @downloads.clear
        @download_condition.broadcast
      end
      FileUtils.rm_rf(@download_directory) if @download_directory
    end
    super
  end

  def quit
    @download_mutex.synchronize do
      @downloads_closed = true
      @download_condition.broadcast
    end
    super
  ensure
    FileUtils.rm_rf(@download_directory) if @download_directory
  end

  private

  def initialize_page(info)
    super
    if @download_directory && @page.context_id
      command(
        "Browser.setDownloadBehavior",
        {
          behavior: "allowAndName",
          downloadPath: @download_directory,
          eventsEnabled: true,
          browserContextId: @page.context_id,
        },
        browser: true,
      )
    end
  end

  def start
    return if @input
    super
    @download_mutex.synchronize { @downloads_closed = false }
    FileUtils.mkdir_p(Downloads::FOLDER)
    @download_directory = Dir.mktmpdir("native-", Downloads::FOLDER)
    command(
      "Browser.setDownloadBehavior",
      { behavior: "allowAndName", downloadPath: @download_directory, eventsEnabled: true },
      browser: true,
    )
  end

  def report_event(event)
    params = event["params"] || {}
    if event["method"] == "Browser.downloadWillBegin"
      @download_mutex.synchronize do
        @download_sequence += 1
        guid = params.fetch("guid")
        state =
          @pages_by_target.values.find do |page|
            page.main_frame_id == params["frameId"] ||
              page.default_contexts.value?(params["frameId"])
          end
        @downloads[guid] = {
          guid: guid,
          filename: params.fetch("suggestedFilename"),
          state: "inProgress",
          sequence: @download_sequence,
          context_id: state&.context_id,
        }
        @download_condition.broadcast
      end
    elsif event["method"] == "Browser.downloadProgress"
      @download_mutex.synchronize do
        @downloads[params["guid"]][:state] = params.fetch("state") if @downloads[params["guid"]]
        @download_condition.broadcast
      end
    end
    super
  end
end

class NativeDownload
  attr_reader :suggested_filename

  def initialize(driver, guid:, filename:)
    @driver = driver
    @guid = guid
    @suggested_filename = filename
  end

  def path = @driver.downloaded_file(@guid)

  def save_as(destination)
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp(path, destination)
    nil
  end
end

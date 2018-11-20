# Helps create links using markdown (where references are at the bottom)
class MarkdownLinker

  def initialize(base_url)
    @base_url = base_url
    @index = 1
    @markdown_links = {}
    @rendered = 1
  end

  def create(title, url)
    @markdown_links[@index] = url.start_with?(@base_url) ? url : "#{@base_url}#{url}"
    result = "[#{title}][#{@index}]"
    @index += 1
    result
  end

  def references
    result = ""
    (@rendered..@index - 1).each do |i|
      result << "[#{i}]: #{@markdown_links[i]}\n"
    end
    @rendered = @index
    result
  end

end

module Onebox
  module Engine
    class GithubPullRequestOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_regexp Regexp.new("^http(?:s)?://(?:www\\.)?(?:(?:\\w)+\\.)?(github)\\.com(?:/)?(?:.)*/pull/")

      def url
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repository]}/pulls/#{match[:number]}"
      end

      private

      #Make an api JSON request, will attempt to authenticate if provided in the engine options
      # Author: Lidlanca
      #: self.options[:github_auth_method]  = :basic | :oauth | nil
      #  :oauth is the recommend way for authentication. when generating token you can control privileges, and you do not expose your password
      #  :basic require username and password provided in options[:github_auth_user , :github_auth_pass]
      #  nil or false will make a request without any authentication. request rate limit are lower.

      def api_json_request url
        box_options = self.options
        case box_options[:github_auth_method] 
          when :basic
            auth = [box_options[:github_auth_user] , box_options[:github_auth_pass]] # user name and password
          when :oauth
            auth = [box_options[:github_auth_token] , "x-oauth-basic"] #oauth does not need password with token
          else
            #request without auth
            return  ::MultiJson.load(open(url,"Accept"=>"application/vnd.github.v3.text+json",read_timeout: timeout))
            
        end
          #Request with auth
          return ::MultiJson.load(open(url,"Accept"=>"application/vnd.github.v3.text+json",http_basic_authentication:auth, read_timeout: timeout))
      end

      def raw 
          @raw ||= api_json_request url
      end
      def match
        @match ||= @url.match(%r{github\.com/(?<owner>[^/]+)/(?<repository>[^/]+)/pull/(?<number>[^/]+)})
      end

      def data
        box_options =  self.options
        result = raw.clone

        pull_status =  "" << {:closed=>"closed",:open=>"open"}[raw["state"].to_sym] << (raw["state"] == "closed" ? (raw["merged"] ? " & merged" : " & declined") : "")  #closed , open
        result['pull_status_str'] = pull_status
        result['pull_status'] = raw["state"]
        result['pull_status_str'] = pull_status
        result['pull_status_str_open'] = raw["state"]=="open"
        result['pull_status_closed_accepted'] = raw["state"]=="closed" && raw["merged"]
        result['pull_status_closed_declined'] = raw["state"]=="closed" && !raw["merged"]
        result['pull_status_class'] =  (raw["merged"] ? "merged": raw["state"] ) # open, merged, close
        result['pull_status_bgcolor'] = {:open=>"#6cc644",:merged =>"6e5494", :closed=> "#bd2c00"}[result['pull_status_class'].to_sym]
        result['inline_css'] = false  #set to true if you need basic styling and you don't have external css
        if box_options[:get_build_status]
          url2 = raw["statuses_url"]
          raw2 =  api_json_request url2  #2nd api request to get build status         
          unless raw2.empty?
            result['build_status'] = "Build status: " +  raw2[0]["state"].to_s.capitalize  + " | " + raw2[0]["description"].to_s
          end
        end

        result['link'] = link
        result['created_at'] = Time.parse(result['created_at']).strftime("%I:%M%p - %d %b %y")
        result
      end
    end
  end
end



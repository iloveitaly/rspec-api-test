require 'json'
require 'active_support/core_ext/hash'

class RSpecAPITest
  def self.config=(config)
    @config = config
  end

  def self.config
    @config ||= {}
  end

  module HTTPHelpers
    class JSONHashResponse < DelegateClass(Hash)
      attr_reader :code, :headers
      def initialize(hash, code, headers)
        @code = code
        @headers = headers
        super(hash.with_indifferent_access)
      end
    end

    class JSONArrayResponse < DelegateClass(Array)
      attr_reader :code, :headers
      def initialize(array, code, headers)
        @code = code
        @headers = headers
        super(array)
      end
    end

    def request(*args)
      request_args = { method: args.first, url: args[1] }

      defaults = RSpecAPITest.config[:defaults] || {}

      if args[2].is_a?(String)
        request_args[:payload] = args[2]
        opts_i = 3
      else
        opts_i = 2
      end

      args[opts_i] ||= {}
      args[opts_i].reverse_merge!(defaults) if defaults

      request_args[:timeout] = args[opts_i].delete(:timeout) if args[opts_i].has_key?(:timeout)
      request_args[:open_timeout] = args[opts_i].delete(:open_timeout) if args[opts_i].has_key?(:open_timeout)
      request_args[:user] = args[opts_i].delete(:user) if args[opts_i].has_key?(:user)
      request_args[:password] = args[opts_i].delete(:password) if args[opts_i].has_key?(:password)
      request_args[:headers] = args[opts_i]

      RestClient::Request.execute(request_args)
    rescue RestClient::Exception => e
      e.response
    end

    classes = {
      Hash => JSONHashResponse,
      Array => JSONArrayResponse
    }

    [:get, :put, :post, :delete, :head].each do |verb|
      self.send(:define_method, verb) do |*args|
        out = [verb, "#{RSpecAPITest.config[:base_url]}#{args[0]}"] +  args[1..-1]
        response = request(*out)
        begin 
          json = JSON.parse(response)
          classes[json.class].new(json, response.code, response.headers)
        rescue JSON::ParserError
          response
        end
      end
    end
  end
end
